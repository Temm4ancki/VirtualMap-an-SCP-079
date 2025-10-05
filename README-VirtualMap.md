# VirtualMap API

VirtualMap is a dynamic room mapping and tracking system for SCP: Breach that provides real-time facility layout information, player tracking, and pathfinding capabilities. It automatically adapts to procedurally generated maps.

## Installation

### 1. File Structure
Ensure the following files are in your `scripts/Breach/virtualmap/` directory:
- `virtualmap_core.as` - Core mapping system
- `virtualmap_GUI.as` - GUI rendering and interaction (if using UI features)

### 2. Integration
Add to your main gamemode file (e.g., `breach.as`):

```angelscript
#include "virtualmap/virtualmap_core.as"

void OnInitialize()
{
    InitializeVirtualMap();
}

void OnWorldLoaded()
{
    OnVirtualMapWorldLoaded();
}
```

### 3. Configuration
The system automatically scans all rooms on world load. Optional settings:

```angelscript
SetMirroringEnabled(true);  // Enable X-axis mirroring for map display
```

## API Reference

### Core Functions

#### `VirtualMap@ GetVirtualMap()`
Returns the global VirtualMap instance.

```angelscript
VirtualMap@ vMap = GetVirtualMap();
if(@vMap != null && vMap.IsMapGenerated())
{
    print("Map has " + vMap.GetRoomCount() + " rooms");
}
```

#### `bool IsVirtualMapReady()`
Check if the map has been scanned and is ready to use.

```angelscript
if(IsVirtualMapReady())
{
    // Safe to use map functions
}
```

#### `VirtualRoom@ GetVirtualRoomByIndex(int index)`
Get a room by its world index.

```angelscript
Room worldRoom = player.GetRoom();
if(worldRoom != NULL)
{
    VirtualRoom@ vRoom = GetVirtualRoomByIndex(worldRoom.GetIndex());
    if(@vRoom != null)
    {
        print("Player is in: " + vRoom.GetShortName());
    }
}
```

#### `VirtualRoom@ GetVirtualRoomByIdentifier(int identifier)`
Get a room by its identifier constant (from uerm.as).

```angelscript
VirtualRoom@ scp173Room = GetVirtualRoomByIdentifier(r_cont1_173);
if(@scp173Room != null)
{
    print("SCP-173 containment found at index: " + scp173Room.roomIndex);
}
```

#### `VirtualRoom@ GetRandomVirtualRoom()`
Get a random accessible room from the map.

```angelscript
VirtualRoom@ randomRoom = GetRandomVirtualRoom();
if(@randomRoom != null && randomRoom.room != NULL)
{
    player.SetPosition(randomRoom.x, randomRoom.y, randomRoom.z, randomRoom.room);
}
```

#### `VirtualRoom@ GetRandomVirtualRoomFromZone(ZoneType zone)`
Get a random room from a specific zone.

```angelscript
VirtualRoom@ lczRoom = GetRandomVirtualRoomFromZone(ZONE_LCZ);
VirtualRoom@ hczRoom = GetRandomVirtualRoomFromZone(ZONE_HCZ);
VirtualRoom@ ezRoom = GetRandomVirtualRoomFromZone(ZONE_EZ);
```

### Pathfinding

#### `array<int> FindRoomPath(int startIndex, int endIndex)`
Find the shortest path between two rooms using BFS.

```angelscript
Room startRoom = player.GetRoom();
VirtualRoom@ targetRoom = GetVirtualRoomByIdentifier(r_room2_nuke);

if(startRoom != NULL && @targetRoom != null)
{
    array<int> path = FindRoomPath(startRoom.GetIndex(), targetRoom.roomIndex);
    
    if(path.size() > 0)
    {
        print("Path length: " + path.size() + " rooms");
        for(int i = 0; i < path.size(); i++)
        {
            VirtualRoom@ pathRoom = GetVirtualRoomByIndex(path[i]);
            if(@pathRoom != null)
            {
                print("Step " + (i+1) + ": " + pathRoom.GetShortName());
            }
        }
    }
}
```

### Player Tracking

#### `void UpdatePlayerRoomTracking(Player player)`
Manually update a player's room tracking data.

```angelscript
void OnPlayerConnect(Player player)
{
    UpdatePlayerRoomTracking(player);
}
```

#### `RoomScanData@ GetRoomScanData(int roomIndex)`
Get real-time player data for a room.

```angelscript
Room currentRoom = player.GetRoom();
if(currentRoom != NULL)
{
    RoomScanData@ scanData = GetRoomScanData(currentRoom.GetIndex());
    if(@scanData != null && scanData.hasPlayers)
    {
        print("Players in room: " + scanData.playerCount);
        for(int i = 0; i < scanData.playerNames.size(); i++)
        {
            print("- " + scanData.playerNames[i] + " [" + scanData.playerRoles[i] + "]");
        }
    }
}
```

#### `RoomScanData@ GetDelayedRoomScanDataForSCP079(int roomIndex)`
Get delayed player data (for SCP-079 gameplay balance).

```angelscript
RoomScanData@ delayedData = GetDelayedRoomScanDataForSCP079(roomIndex);
```

#### `array<VirtualRoom@> GetOccupiedRooms()`
Get all rooms that currently have players in them.

```angelscript
array<VirtualRoom@> occupiedRooms = GetOccupiedRooms();
for(int i = 0; i < occupiedRooms.size(); i++)
{
    VirtualRoom@ vRoom = occupiedRooms[i];
    if(@vRoom != null)
    {
        print("Players detected in: " + vRoom.GetShortName());
    }
}
```

### VirtualRoom Class

#### Properties
```angelscript
Room room;                      // World room reference
int roomIndex;                  // World room index
int roomIdentifier;             // Room type identifier
string roomName;                // Full room name
float x, y, z;                  // Room position
array<int> connections;         // Connected room indices
array<Door> doorConnections;    // Doors to connected rooms
bool isAccessible;              // Room accessibility flag
ZoneType zoneType;              // Zone classification
```

#### Methods

**`string GetShortName()`**
Get abbreviated room name for display.

```angelscript
string shortName = vRoom.GetShortName();  // "SCP-173" instead of "cont1_173_intro"
```

**`array<Player> GetPlayersInRoom()`**
Get all players currently in this room.

```angelscript
array<Player> players = vRoom.GetPlayersInRoom();
for(int i = 0; i < players.size(); i++)
{
    print("Player: " + players[i].GetName());
}
```

**`bool HasDoorAccess()`**
Check if room has door connections.

```angelscript
if(vRoom.HasDoorAccess())
{
    print("Room has " + vRoom.doorConnections.size() + " doors");
}
```

**`float GetDistanceTo(VirtualRoom@ other)`**
Calculate distance to another room.

```angelscript
float distance = roomA.GetDistanceTo(roomB);
```

### VirtualMap Class Methods

#### `void ScanAllRooms()`
Manually trigger a full map scan.

```angelscript
VirtualMap@ vMap = GetVirtualMap();
vMap.ScanAllRooms();
```

#### `void RefreshMap()`
Refresh the entire map (rescans all rooms).

```angelscript
vMap.RefreshMap();
```

#### `array<VirtualRoom@> GetRoomsByZone(ZoneType zone)`
Get all rooms in a specific zone.

```angelscript
array<VirtualRoom@> hczRooms = vMap.GetRoomsByZone(ZONE_HCZ);
```

#### `void GetMapBounds(float& out minX, float& out maxX, float& out minZ, float& out maxZ)`
Get the map's bounding box coordinates.

```angelscript
float minX, maxX, minZ, maxZ;
vMap.GetMapBounds(minX, maxX, minZ, maxZ);
print("Map size: " + (maxX - minX) + " x " + (maxZ - minZ));
```

### Zone Types

```angelscript
enum ZoneType
{
    ZONE_UNKNOWN = 0,
    ZONE_LCZ = 1,      // Light Containment Zone
    ZONE_HCZ = 2,      // Heavy Containment Zone
    ZONE_EZ = 3,       // Entrance Zone
    ZONE_CHECKPOINT = 4,
    ZONE_SURFACE = 5
}
```

### Utility Functions

#### `string GetShortRoomName(const string& in fullName)`
Convert full room name to short display name.

```angelscript
string shortName = GetShortRoomName("cont1_173_intro");  // Returns "SCP-173"
```

#### `void GetZoneColor(ZoneType zone, int& out r, int& out g, int& out b)`
Get RGB color values for a zone type.

```angelscript
int r, g, b;
GetZoneColor(ZONE_LCZ, r, g, b);  // Returns yellow (255, 255, 0)
```

#### `bool IsLCZRoom(int identifier)`
#### `bool IsHCZRoom(int identifier)`
#### `bool IsEZRoom(int identifier)`
#### `bool IsCheckpointRoom(int identifier, const string& in roomName)`

Check if a room belongs to a specific zone.

```angelscript
if(IsLCZRoom(roomIdentifier))
{
    print("This is a Light Containment Zone room");
}
```

## Usage Examples

### Example 1: Teleport Player to Random SCP Containment

```angelscript
void TeleportToRandomSCP(Player player)
{
    VirtualMap@ vMap = GetVirtualMap();
    if(@vMap == null || !vMap.IsMapGenerated()) return;
    
    array<int> scpRooms = {r_cont1_173, r_cont2_049, r_cont1_106, r_cont2c_096};
    int randomSCP = scpRooms[rand(0, scpRooms.size() - 1)];
    
    VirtualRoom@ scpRoom = GetVirtualRoomByIdentifier(randomSCP);
    if(@scpRoom != null && scpRoom.room != NULL)
    {
        Entity roomEnt = scpRoom.room.GetEntity();
        if(roomEnt != NULL)
        {
            player.SetPosition(roomEnt.PositionX(), roomEnt.PositionY(), roomEnt.PositionZ(), scpRoom.room);
        }
    }
}
```

### Example 2: Find Nearest Checkpoint

```angelscript
VirtualRoom@ FindNearestCheckpoint(Player player)
{
    Room currentRoom = player.GetRoom();
    if(currentRoom == NULL) return null;
    
    VirtualRoom@ currentVRoom = GetVirtualRoomByIndex(currentRoom.GetIndex());
    if(@currentVRoom == null) return null;
    
    VirtualMap@ vMap = GetVirtualMap();
    if(@vMap == null) return null;
    
    VirtualRoom@ nearestCheckpoint = null;
    float nearestDistance = 999999.0;
    
    for(int i = 0; i < vMap.rooms.size(); i++)
    {
        VirtualRoom@ vRoom = @vMap.rooms[i];
        if(vRoom.zoneType == ZONE_CHECKPOINT)
        {
            float distance = currentVRoom.GetDistanceTo(vRoom);
            if(distance < nearestDistance)
            {
                nearestDistance = distance;
                @nearestCheckpoint = vRoom;
            }
        }
    }
    
    return nearestCheckpoint;
}
```

### Example 3: Monitor All Occupied Rooms

```angelscript
void MonitorOccupiedRooms()
{
    array<VirtualRoom@> occupied = GetOccupiedRooms();
    
    for(int i = 0; i < occupied.size(); i++)
    {
        VirtualRoom@ vRoom = occupied[i];
        if(@vRoom == null) continue;
        
        array<Player> players = vRoom.GetPlayersInRoom();
        
        print("[" + vRoom.GetShortName() + "] " + players.size() + " players:");
        for(int j = 0; j < players.size(); j++)
        {
            print("  - " + players[j].GetName());
        }
    }
}
```

### Example 4: Create Navigation System

```angelscript
void NavigatePlayerToRoom(Player player, int targetRoomIdentifier)
{
    Room currentRoom = player.GetRoom();
    if(currentRoom == NULL) return;
    
    VirtualRoom@ targetVRoom = GetVirtualRoomByIdentifier(targetRoomIdentifier);
    if(@targetVRoom == null) return;
    
    array<int> path = FindRoomPath(currentRoom.GetIndex(), targetVRoom.roomIndex);
    
    if(path.size() > 1)
    {
        VirtualRoom@ nextRoom = GetVirtualRoomByIndex(path[1]);
        if(@nextRoom != null)
        {
            player.SendMessage("Navigate to: " + nextRoom.GetShortName());
            player.SendMessage("Distance: " + path.size() + " rooms");
        }
    }
}
```

## Performance Considerations

- Map scanning occurs once on world load (2-3 second delay)
- Player tracking updates every 50ms (configurable via `FAST_UPDATE_INTERVAL`)
- Room scan data is cached and only updated when players move
- Pathfinding uses BFS algorithm (efficient for facility-sized maps)
- Excluded rooms (SCP-106 dimension, SCP-1499, gates) are not tracked

## Troubleshooting

**Map not generating:**
- Ensure `OnVirtualMapWorldLoaded()` is called after world loads
- Check console for "[VirtualMap]" initialization messages
- Verify `IsVirtualMapReady()` returns true before using API

**Player tracking not working:**
- Call `UpdatePlayerRoomTracking(player)` on player connect
- Ensure players have valid room assignments
- Check that player is not SCP-079 (excluded from tracking)

**Pathfinding returns empty array:**
- Verify both rooms exist and are accessible
- Check that rooms are connected via doors
- Some rooms may be isolated (no door connections)

## Advanced Features

### Custom Room Exclusion

Modify `ShouldExcludeRoom()` in virtualmap_core.as:

```angelscript
bool ShouldExcludeRoom(int identifier)
{
    return (identifier == r_dimension_106 || 
            identifier == r_dimension_1499 || 
            identifier == r_gate_a || 
            identifier == r_gate_b ||
            identifier == r_gate_a_b ||
            identifier == YOUR_CUSTOM_ROOM);
}
```

### Coordinate Mirroring

The system supports X-axis mirroring for map display:

```angelscript
float mirroredX = GetMirroredXCoordinate(originalX);
float mirrorAxis = GetMirrorAxis();
```

### SCP-079 Integration

VirtualMap includes built-in delay for SCP-079 player detection:

```angelscript
const int SCP079_DELAY_TICKS = 60;  // ~3 second delay
```

This prevents instant player detection for gameplay balance.
