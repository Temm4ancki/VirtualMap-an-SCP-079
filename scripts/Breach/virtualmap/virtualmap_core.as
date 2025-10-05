#include "../include/uerm.as"

const array<int> ZONE_COLOR_LCZ = {255, 255, 0};
const array<int> ZONE_COLOR_HCZ = {255, 0, 0};
const array<int> ZONE_COLOR_EZ = {0, 0, 150};
const array<int> ZONE_COLOR_CHECKPOINT = {255, 165, 0};
const array<int> ZONE_COLOR_SURFACE = {100, 100, 100};
const array<int> ZONE_COLOR_UNKNOWN = {64, 64, 64};

const float COLOR_MULTIPLIER_CAMERA_AND_PLAYERS = 2.0;
const float COLOR_MULTIPLIER_CAMERA = 1.5;
const float COLOR_MULTIPLIER_PLAYERS = 1.5;
const float COLOR_MULTIPLIER_EMPTY_NO_CAMERA = 0.25;
const float COLOR_MULTIPLIER_NO_CAMERA = 1.0;

const array<int> COLOR_CURRENT_VIEWING_ROOM = {0, 255, 255};

class RoomScanData
{
    RoomScanData()
    {
        roomIndex = -1; 
        playerCount = 0;
        lastUpdateTime = 0; 
        hasPlayers = false;
        needsUpdate = false;
    }
    
    int roomIndex, playerCount, lastUpdateTime;
    bool hasPlayers, needsUpdate;
    array<string> playerNames, playerRoles;
}

class PlayerTrackingData
{
    PlayerTrackingData()
    {
        playerIndex = -1;
        currentRoomIndex = -1;
        lastRoomIndex = -1;
        lastUpdateTime = 0;
        isValid = false;
    }
    
    int playerIndex;
    int currentRoomIndex;
    int lastRoomIndex;
    int lastUpdateTime;
    bool isValid;
}

class VirtualRoom
{
    VirtualRoom() 
    { 
        room = NULL;
        roomIndex = -1;
        roomIdentifier = -1;
        roomName = "";
        x = 0.0;
        y = 0.0;
        z = 0.0;
        connections.resize(0);
        doorConnections.resize(0);
        isAccessible = true;
        zoneType = ZONE_UNKNOWN;
    }
    
    VirtualRoom(Room r)
    {
        if(r != NULL)
        {
            room = r;
            roomIndex = r.GetIndex();
            roomIdentifier = r.GetIdentifier();
            roomName = r.GetName();
            
            Entity roomEntity = r.GetEntity();
            if(roomEntity != NULL)
            {
                x = roomEntity.PositionX();
                y = roomEntity.PositionY();
                z = roomEntity.PositionZ();
            }
            
            connections.resize(0);
            doorConnections.resize(0);
            isAccessible = true;
            zoneType = DetermineZoneType(roomIdentifier);
        }
    }
    
    Room room;
    int roomIndex;
    int roomIdentifier;
    string roomName;
    float x, y, z;
    array<int> connections;
    array<Door> doorConnections;
    bool isAccessible;
    ZoneType zoneType;
    
    array<Player> GetPlayersInRoom()
    {
        array<Player> playersInRoom;
        
        if(room == NULL) return playersInRoom;
        
        RoomScanData@ scanData = GetRoomScanData(roomIndex);
        if(@scanData != null && scanData.hasPlayers)
        {
            for(int i = 0; i < g_PlayerTracking.size(); i++)
            {
                PlayerTrackingData@ tracking = @g_PlayerTracking[i];
                if(@tracking == null || !tracking.isValid) continue;
                if(tracking.currentRoomIndex != roomIndex) continue;
                
                Player p = GetPlayer(i);
                if(p != NULL && !p.IsDead())
                {
                    info_Player@ playerInfo = GetPlayerInfo(p);
                    if(@playerInfo != null && @playerInfo.pClass != null && playerInfo.pClass.roleid == ROLE_SCP_079)
                        continue;
                    
                    playersInRoom.push_back(p);
                }
            }
        }
        
        return playersInRoom;
    }
    
    string GetShortName()
    {
        return GetShortRoomName(roomName);
    }

    bool HasDoorAccess()
    {
        return doorConnections.size() > 0;
    }

    float GetDistanceTo(VirtualRoom@ other)
    {
        if(@other == null) return 999999.0;
        
        float dx = x - other.x;
        float dz = z - other.z;
        return sqrt(dx * dx + dz * dz);
    }
    
    private ZoneType DetermineZoneType(int identifier)
    {
        if(IsCheckpointRoom(identifier, roomName)) return ZONE_CHECKPOINT;
        if(IsLCZRoom(identifier)) return ZONE_LCZ;
        if(IsHCZRoom(identifier)) return ZONE_HCZ;
        if(IsEZRoom(identifier)) return ZONE_EZ;
        return ZONE_UNKNOWN;
    }
}

enum ZoneType
{
    ZONE_UNKNOWN = 0,
    ZONE_LCZ = 1,
    ZONE_HCZ = 2,
    ZONE_EZ = 3,
    ZONE_CHECKPOINT = 4,
    ZONE_SURFACE = 5
}

class VirtualMap
{
    VirtualMap() 
    { 
        rooms.resize(0);
        isGenerated = false;
        lastScanTime = 0;
        totalRoomsScanned = 0;
        mirrorAxisX = 0.0;
        enableMirroring = true;
    }
    
    array<VirtualRoom> rooms;
    bool isGenerated;
    int lastScanTime;
    int totalRoomsScanned;
    float mirrorAxisX;
    bool enableMirroring;

    void ScanAllRooms()
    {
        rooms.resize(0);
        totalRoomsScanned = 0;

        if(enableMirroring)
        {
            CalculateMirrorAxisFromWorld();
        }

        for(int i = 0; i < MAX_ROOMS; i++)
        {
            Room r = world.GetRoomByIndex(i);
            if(r != NULL)
            {
                VirtualRoom vRoom = VirtualRoom(r);

                if(!ShouldExcludeRoom(vRoom.roomIdentifier))
                {
                    if(enableMirroring)
                    {
                        vRoom.x = MirrorXCoordinate(vRoom.x);
                    }
                    
                    rooms.push_back(vRoom);
                    totalRoomsScanned++;
                }
            }
        }

        BuildRoomConnections();
        isGenerated = true;
        lastScanTime = totalRoomsScanned;
        
        if(enableMirroring)
        {
            print("[VirtualMap] Found " + totalRoomsScanned + " accessible rooms + mirroring.");
        }
        else
        {
            print("[VirtualMap] Found " + totalRoomsScanned + " accessible rooms.");
        }
    }
    
    private void CalculateMirrorAxisFromWorld()
    {
        float minX = 999999.0;
        float maxX = -999999.0;
        
        for(int i = 0; i < MAX_ROOMS; i++)
        {
            Room r = world.GetRoomByIndex(i);
            if(r != NULL)
            {
                int identifier = r.GetIdentifier();
                if(!ShouldExcludeRoom(identifier))
                {
                    Entity roomEntity = r.GetEntity();
                    if(roomEntity != NULL)
                    {
                        float x = roomEntity.PositionX();
                        if(x < minX) minX = x;
                        if(x > maxX) maxX = x;
                    }
                }
            }
        }
        
        mirrorAxisX = (minX + maxX) / 2.0;
    }
    
    private float MirrorXCoordinate(float originalX)
    {
        return mirrorAxisX + (mirrorAxisX - originalX);
    }
    
    void SetMirroringEnabled(bool enabled)
    {
        enableMirroring = enabled;
    }
    
    bool IsMirroringEnabled()
    {
        return enableMirroring;
    }

    bool ShouldExcludeRoom(int identifier)
    {
        return (identifier == r_dimension_106 || 
                identifier == r_dimension_1499 || 
                identifier == r_gate_a || 
                identifier == r_gate_b ||
                identifier == r_gate_a_b);
    }

    void BuildRoomConnections()
    {
        int totalConnections = 0;
        
        for(int i = 0; i < rooms.size(); i++)
        {
            VirtualRoom@ currentRoom = @rooms[i];
            if(currentRoom.room == NULL) continue;

            for(int doorIndex = 0; doorIndex < MAX_ROOM_DOORS; doorIndex++)
            {
                Door door = currentRoom.room.GetDoor(doorIndex);
                if(door == NULL) continue;

                for(int j = 0; j < rooms.size(); j++)
                {
                    if(i == j) continue;
                    
                    VirtualRoom@ otherRoom = @rooms[j];
                    if(otherRoom.room == NULL) continue;
                    
                    if(AreRoomsConnectedByDoor(currentRoom.room, otherRoom.room, door))
                    {
                        bool alreadyConnected = false;
                        for(int k = 0; k < currentRoom.connections.size(); k++)
                        {
                            if(currentRoom.connections[k] == otherRoom.roomIndex)
                            {
                                alreadyConnected = true;
                                break;
                            }
                        }
                        
                        if(!alreadyConnected)
                        {
                            rooms[i].connections.push_back(otherRoom.roomIndex);
                            rooms[i].doorConnections.push_back(door);
                            totalConnections++;
                        }
                    }
                }
            }
        }
        
        print("[VirtualMap] Built " + totalConnections + " room connections.");
    }
    
    bool AreRoomsConnectedByDoor(Room room1, Room room2, Door door)
    {
        if(room1 == NULL || room2 == NULL || door == NULL) return false;
        
        Entity doorEntity = door.GetEntity();
        Entity room1Entity = room1.GetEntity();
        Entity room2Entity = room2.GetEntity();
        
        if(doorEntity == NULL || room1Entity == NULL || room2Entity == NULL) return false;
        
        float doorX = doorEntity.PositionX();
        float doorZ = doorEntity.PositionZ();
        float room1X = room1Entity.PositionX();
        float room1Z = room1Entity.PositionZ();
        float room2X = room2Entity.PositionX();
        float room2Z = room2Entity.PositionZ();

        float distToRoom1 = sqrt((doorX - room1X) * (doorX - room1X) + (doorZ - room1Z) * (doorZ - room1Z));
        float distToRoom2 = sqrt((doorX - room2X) * (doorX - room2X) + (doorZ - room2Z) * (doorZ - room2Z));
        
        const float CONNECTION_THRESHOLD = 2000.0;
        return (distToRoom1 < CONNECTION_THRESHOLD && distToRoom2 < CONNECTION_THRESHOLD);
    }

    VirtualRoom@ GetRoomByIndex(int index)
    {
        for(int i = 0; i < rooms.size(); i++)
        {
            if(rooms[i].roomIndex == index)
                return @rooms[i];
        }
        return null;
    }

    VirtualRoom@ GetRoomByIdentifier(int identifier)
    {
        for(int i = 0; i < rooms.size(); i++)
        {
            if(rooms[i].roomIdentifier == identifier)
                return @rooms[i];
        }
        return null;
    }

    array<VirtualRoom@> GetRoomsByZone(ZoneType zone)
    {
        array<VirtualRoom@> zoneRooms;
        
        for(int i = 0; i < rooms.size(); i++)
        {
            if(rooms[i].zoneType == zone)
                zoneRooms.push_back(@rooms[i]);
        }
        
        return zoneRooms;
    }

    array<VirtualRoom@> GetRoomsWithPlayers()
    {
        array<VirtualRoom@> occupiedRooms;
        
        for(int i = 0; i < rooms.size(); i++)
        {
            array<Player> playersInRoom = rooms[i].GetPlayersInRoom();
            if(playersInRoom.size() > 0)
                occupiedRooms.push_back(@rooms[i]);
        }
        
        return occupiedRooms;
    }

    array<int> FindPath(int startRoomIndex, int endRoomIndex)
    {
        array<int> path;
        
        VirtualRoom@ startRoom = GetRoomByIndex(startRoomIndex);
        VirtualRoom@ endRoom = GetRoomByIndex(endRoomIndex);
        
        if(@startRoom == null || @endRoom == null) return path;

        array<int> queue;
        array<bool> visited(MAX_ROOMS, false);
        array<int> parent(MAX_ROOMS, -1);
        
        queue.push_back(startRoomIndex);
        visited[startRoomIndex] = true;
        
        while(queue.size() > 0)
        {
            int currentIndex = queue[0];
            queue.removeAt(0);
            
            if(currentIndex == endRoomIndex)
            {
                int current = endRoomIndex;
                while(current != -1)
                {
                    path.insertAt(0, current);
                    current = parent[current];
                }
                break;
            }
            
            VirtualRoom@ currentRoom = GetRoomByIndex(currentIndex);
            if(@currentRoom != null)
            {
                for(int i = 0; i < currentRoom.connections.size(); i++)
                {
                    int neighborIndex = currentRoom.connections[i];
                    if(!visited[neighborIndex])
                    {
                        visited[neighborIndex] = true;
                        parent[neighborIndex] = currentIndex;
                        queue.push_back(neighborIndex);
                    }
                }
            }
        }
        
        return path;
    }

    int GetRoomCount() { return rooms.size(); }
    int GetTotalConnections()
    {
        int total = 0;
        for(int i = 0; i < rooms.size(); i++)
            total += rooms[i].connections.size();
        return total;
    }
    
    bool IsMapGenerated() { return isGenerated; }
    int GetLastScanTime() { return lastScanTime; }

    VirtualRoom@ GetRandomRoom()
    {
        if(rooms.size() == 0) return null;
        
        int randomIndex = rand(0, rooms.size() - 1);
        return @rooms[randomIndex];
    }

    VirtualRoom@ GetRandomRoomFromZone(ZoneType zone)
    {
        array<VirtualRoom@> zoneRooms = GetRoomsByZone(zone);
        if(zoneRooms.size() == 0) return null;
        
        int randomIndex = rand(0, zoneRooms.size() - 1);
        return zoneRooms[randomIndex];
    }

    void RefreshMap()
    {
        print("[VirtualMap] Refreshing virtual map...");
        ScanAllRooms();
    }

    void GetMapBounds(float& out minX, float& out maxX, float& out minZ, float& out maxZ)
    {
        if(rooms.size() == 0)
        {
            minX = maxX = minZ = maxZ = 0.0;
            return;
        }
        
        minX = maxX = rooms[0].x;
        minZ = maxZ = rooms[0].z;
        
        for(int i = 1; i < rooms.size(); i++)
        {
            if(rooms[i].x < minX) minX = rooms[i].x;
            if(rooms[i].x > maxX) maxX = rooms[i].x;
            if(rooms[i].z < minZ) minZ = rooms[i].z;
            if(rooms[i].z > maxZ) maxZ = rooms[i].z;
        }
    }

    float GetMirroredXCoordinate(float originalX)
    {
        if(!enableMirroring) return originalX;
        return MirrorXCoordinate(originalX);
    }
    
    float GetMirrorAxis() { return mirrorAxisX; }
}

bool IsLCZRoom(int identifier)
{
    return (identifier >= r_room1_storage && identifier <= r_room2_checkpoint_lcz_hcz) ||
           (identifier == r_room2_closets_2);
}

bool IsHCZRoom(int identifier)
{
    return (identifier >= r_room1_dead_end_hcz && identifier <= r_room2_checkpoint_hcz_ez) ||
           (identifier == r_cont3_009) ||
           (identifier == r_room2_tesla_2_hcz);
}

bool IsEZRoom(int identifier)
{
    return (identifier >= r_gate_a_entrance && identifier <= r_room4_2_ez) ||
           (identifier == r_gate_a_b);
}

bool IsCheckpointRoom(int identifier, const string& in roomName)
{
    return (identifier == r_room2_checkpoint_lcz_hcz || 
            identifier == r_room2_checkpoint_hcz_ez ||
            roomName.findFirst("checkpoint") >= 0);
}

string GetShortRoomName(const string& in fullName)
{
    if(fullName.findFirst("cont1_173") >= 0) return "SCP-173";
    if(fullName.findFirst("cont2_049") >= 0) return "SCP-049";
    if(fullName.findFirst("cont1_106") >= 0) return "SCP-106";
    if(fullName.findFirst("cont3_966") >= 0) return "SCP-966";
    if(fullName.findFirst("cont2c_096") >= 0) return "SCP-096";
    if(fullName.findFirst("cont1_079") >= 0) return "SCP-079";
    if(fullName.findFirst("cont1_035") >= 0) return "SCP-035";
    if(fullName.findFirst("cont2_008") >= 0) return "SCP-008";
    if(fullName.findFirst("cont1_914") >= 0) return "SCP-914";
    if(fullName.findFirst("cont1_005") >= 0) return "SCP-005";
    if(fullName.findFirst("cont2_500_1499") >= 0) return "SCP-500/1499";

    if(fullName.findFirst("gate_a") >= 0) return "Gate A";
    if(fullName.findFirst("gate_b") >= 0) return "Gate B";
    if(fullName.findFirst("checkpoint") >= 0) return "Checkpoint";

    if(fullName.findFirst("storage") >= 0) return "Storage";
    if(fullName.findFirst("office") >= 0) return "Office";
    if(fullName.findFirst("cafeteria") >= 0) return "Cafeteria";
    if(fullName.findFirst("servers") >= 0) return "Server Room";
    if(fullName.findFirst("nuke") >= 0) return "Warhead";
    if(fullName.findFirst("medibay") >= 0) return "Medical";
    if(fullName.findFirst("tesla") >= 0) return "Tesla Gate";
    if(fullName.findFirst("elevator") >= 0) return "Elevator";
    
    if(fullName.length() > 12)
        return fullName.substr(0, 12) + "...";
    
    return fullName;
}

void GetZoneColor(ZoneType zone, int& out r, int& out g, int& out b)
{
    array<int> color;
    
    switch(zone)
    {
        case ZONE_LCZ:
            color = ZONE_COLOR_LCZ;
            break;
        case ZONE_HCZ:
            color = ZONE_COLOR_HCZ;
            break;
        case ZONE_EZ:
            color = ZONE_COLOR_EZ;
            break;
        case ZONE_CHECKPOINT:
            color = ZONE_COLOR_CHECKPOINT;
            break;
        case ZONE_SURFACE:
            color = ZONE_COLOR_SURFACE;
            break;
        default:
            color = ZONE_COLOR_UNKNOWN;
            break;
    }
    
    r = color[0];
    g = color[1];
    b = color[2];
}

array<RoomScanData> g_ActiveRoomData;
array<PlayerTrackingData> g_PlayerTracking(MAX_PLAYERS + 1);
int g_UpdateCounter = 0;
const int FAST_UPDATE_INTERVAL = 50;
const int SCP079_DELAY_TICKS = 60;

VirtualMap g_VirtualMap = VirtualMap();

void InitializeVirtualMap()
{
    for(int i = 0; i <= MAX_PLAYERS; i++)
    {
        g_PlayerTracking[i] = PlayerTrackingData();
        g_PlayerTracking[i].playerIndex = i;
    }
    
    g_ActiveRoomData.resize(0);
    
    print("[VirtualMap] Virtual Map system initialized.");
}

void OnVirtualMapWorldLoaded()
{
    CreateTimer(DelayedVirtualMapScan, 2000, false);
    CreateTimer(RealTimePlayerTracking, FAST_UPDATE_INTERVAL, true);
}

void DelayedVirtualMapScan()
{
    g_VirtualMap.ScanAllRooms();
    CreateTimer(InitializePlayerTracking, 1000, false);
}

void InitializePlayerTracking()
{
    if(!IsVirtualMapReady())
    {
        CreateTimer(InitializePlayerTracking, 1000, false);
        return;
    }
    
    for(int i = 0; i < connPlayers.size(); i++)
    {
        Player p = connPlayers[i];
        if(p != NULL && !p.IsDead())
        {
            int playerIndex = p.GetIndex();
            if(playerIndex >= 0 && playerIndex < g_PlayerTracking.size())
            {
                g_PlayerTracking[playerIndex].isValid = true;
                UpdatePlayerRoomTracking(p);
            }
        }
    }
}

void RealTimePlayerTracking()
{
    if(!IsVirtualMapReady()) return;
    
    g_UpdateCounter++;
    bool hasChanges = false;

    for(int i = 0; i < connPlayers.size(); i++)
    {
        Player p = connPlayers[i];
        if(p == NULL || p.IsDead()) continue;
        
        int playerIndex = p.GetIndex();
        if(playerIndex < 0 || playerIndex >= g_PlayerTracking.size()) continue;

        info_Player@ playerInfo = GetPlayerInfo(p);
        if(@playerInfo != null && @playerInfo.pClass != null && playerInfo.pClass.roleid == ROLE_SCP_079)
            continue;
        
        PlayerTrackingData@ tracking = @g_PlayerTracking[playerIndex];
        if(@tracking == null) continue;
        
        tracking.isValid = true;
        
        Room currentRoom = p.GetRoom();
        int currentRoomIndex = (currentRoom != NULL) ? currentRoom.GetIndex() : -1;
        
        if(currentRoomIndex != tracking.currentRoomIndex)
        {
            tracking.lastRoomIndex = tracking.currentRoomIndex;
            tracking.currentRoomIndex = currentRoomIndex;
            tracking.lastUpdateTime = g_UpdateCounter;
            hasChanges = true;

            MarkRoomForUpdate(tracking.lastRoomIndex);
            MarkRoomForUpdate(currentRoomIndex);
        }
    }

    for(int i = 0; i < g_PlayerTracking.size(); i++)
    {
        PlayerTrackingData@ tracking = @g_PlayerTracking[i];
        if(@tracking == null || !tracking.isValid) continue;
        
        Player p = GetPlayer(i);
        if(p == NULL || p.IsDead())
        {
            if(tracking.currentRoomIndex != -1)
            {
                MarkRoomForUpdate(tracking.currentRoomIndex);
                tracking.currentRoomIndex = -1;
                hasChanges = true;
            }
            tracking.isValid = false;
        }
    }

    if(hasChanges)
    {
        UpdateChangedRooms();
    }
}

void MarkRoomForUpdate(int roomIndex)
{
    if(roomIndex == -1) return;
    
    for(int i = 0; i < g_ActiveRoomData.size(); i++)
    {
        if(g_ActiveRoomData[i].roomIndex == roomIndex)
        {
            g_ActiveRoomData[i].needsUpdate = true;
            return;
        }
    }

    RoomScanData newData = RoomScanData();
    newData.roomIndex = roomIndex;
    newData.needsUpdate = true;
    g_ActiveRoomData.push_back(newData);
}

void UpdateChangedRooms()
{
    VirtualMap@ vMap = GetVirtualMap();
    if(@vMap == null) return;
    
    for(int i = g_ActiveRoomData.size() - 1; i >= 0; i--)
    {
        RoomScanData@ scanData = @g_ActiveRoomData[i];
        if(@scanData == null || !scanData.needsUpdate) continue;
        
        VirtualRoom@ vRoom = vMap.GetRoomByIndex(scanData.roomIndex);
        if(@vRoom == null) continue;
        
        array<Player> playersInRoom;
        for(int j = 0; j < g_PlayerTracking.size(); j++)
        {
            PlayerTrackingData@ tracking = @g_PlayerTracking[j];
            if(@tracking == null || !tracking.isValid) continue;
            if(tracking.currentRoomIndex != scanData.roomIndex) continue;
            
            Player p = GetPlayer(j);
            if(p != NULL && !p.IsDead())
            {
                info_Player@ playerInfo = GetPlayerInfo(p);
                if(@playerInfo != null && @playerInfo.pClass != null && playerInfo.pClass.roleid == ROLE_SCP_079)
                    continue;
                
                playersInRoom.push_back(p);
            }
        }
        
        scanData.playerCount = playersInRoom.size();
        scanData.hasPlayers = playersInRoom.size() > 0;
        scanData.lastUpdateTime = g_UpdateCounter;
        scanData.needsUpdate = false;
        
        scanData.playerNames.resize(0);
        scanData.playerRoles.resize(0);
        
        for(int k = 0; k < playersInRoom.size(); k++)
        {
            Player p = playersInRoom[k];
            if(p != NULL)
            {
                scanData.playerNames.push_back(p.GetName());
                
                info_Player@ pInfo = GetPlayerInfo(p);
                if(@pInfo != null && @pInfo.pClass != null)
                {
                    scanData.playerRoles.push_back(pInfo.pClass.name);
                }
                else
                {
                    scanData.playerRoles.push_back("Unknown");
                }
            }
        }
        
        if(!scanData.hasPlayers)
        {
            g_ActiveRoomData.removeAt(i);
        }
    }
}

void UpdatePlayerRoomTracking(Player player)
{
    if(player == NULL) return;
    
    int playerIndex = player.GetIndex();
    if(playerIndex < 0 || playerIndex >= g_PlayerTracking.size()) return;
    
    PlayerTrackingData@ tracking = @g_PlayerTracking[playerIndex];
    if(@tracking == null) return;
    
    Room currentRoom = player.GetRoom();
    int currentRoomIndex = (currentRoom != NULL) ? currentRoom.GetIndex() : -1;
    
    tracking.currentRoomIndex = currentRoomIndex;
    tracking.lastUpdateTime = g_UpdateCounter;
    tracking.isValid = true;
    
    if(currentRoomIndex != -1)
    {
        MarkRoomForUpdate(currentRoomIndex);
    }
}

RoomScanData@ GetRoomScanData(int roomIndex)
{
    for(int i = 0; i < g_ActiveRoomData.size(); i++)
    {
        if(g_ActiveRoomData[i].roomIndex == roomIndex)
        {
            return @g_ActiveRoomData[i];
        }
    }
    
    return null;
}

RoomScanData@ GetDelayedRoomScanDataForSCP079(int roomIndex)
{
    RoomScanData@ realTimeData = GetRoomScanData(roomIndex);
    
    if(@realTimeData == null)
    {
        RoomScanData emptyData = RoomScanData();
        emptyData.roomIndex = roomIndex;
        emptyData.hasPlayers = false;
        emptyData.playerCount = 0;
        emptyData.lastUpdateTime = g_UpdateCounter;
        return @emptyData;
    }
    
    if(!realTimeData.hasPlayers)
    {
        return realTimeData;
    }
    
    int timeSinceUpdate = g_UpdateCounter - realTimeData.lastUpdateTime;
    
    if(timeSinceUpdate < SCP079_DELAY_TICKS)
    {
        RoomScanData emptyData = RoomScanData();
        emptyData.roomIndex = roomIndex;
        emptyData.hasPlayers = false;
        emptyData.playerCount = 0;
        emptyData.lastUpdateTime = g_UpdateCounter;
        return @emptyData;
    }
    
    return realTimeData;
}

void OnPlayerConnect(Player player)
{
    if(player == NULL) return;
    UpdatePlayerRoomTracking(player);
}

VirtualMap@ GetVirtualMap()
{
    return @g_VirtualMap;
}

bool IsVirtualMapReady()
{
    return g_VirtualMap.IsMapGenerated();
}

VirtualRoom@ GetVirtualRoomByIndex(int index)
{
    return g_VirtualMap.GetRoomByIndex(index);
}

VirtualRoom@ GetVirtualRoomByIdentifier(int identifier)
{
    return g_VirtualMap.GetRoomByIdentifier(identifier);
}

array<VirtualRoom@> GetOccupiedRooms()
{
    return g_VirtualMap.GetRoomsWithPlayers();
}

array<int> FindRoomPath(int startIndex, int endIndex)
{
    return g_VirtualMap.FindPath(startIndex, endIndex);
}

VirtualRoom@ GetRandomVirtualRoom()
{
    return g_VirtualMap.GetRandomRoom();
}

VirtualRoom@ GetRandomVirtualRoomFromZone(ZoneType zone)
{
    return g_VirtualMap.GetRandomRoomFromZone(zone);
}

bool IsMirroringEnabled()
{
    return g_VirtualMap.IsMirroringEnabled();
}

void SetMirroringEnabled(bool enabled)
{
    g_VirtualMap.SetMirroringEnabled(enabled);
}

float GetMirroredXCoordinate(float originalX)
{
    return g_VirtualMap.GetMirroredXCoordinate(originalX);
}

float GetMirrorAxis()
{
    return g_VirtualMap.GetMirrorAxis();
}
