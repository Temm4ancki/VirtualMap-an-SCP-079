#include "../include/uerm.as"
#include "scp079_base.as"
#include "scp079_hud.as"
#include "scp079_doors.as"

class CustomCamera
{
    CustomCamera() 
    { 
        localX = 0.0; localY = 0.0; localZ = 0.0;
        pitch = 0.0; yaw = 0.0;
        roomIdentifier = -1; roomName = "";
    }
    
    CustomCamera(float localX, float localY, float localZ, float pitch, float yaw, int roomIdentifier, const string& in roomName)
    {
        this.localX = localX; this.localY = localY; this.localZ = localZ;
        this.pitch = pitch; this.yaw = yaw;
        this.roomIdentifier = roomIdentifier; this.roomName = roomName;
    }
    
    float localX, localY, localZ, pitch, yaw;
    int roomIdentifier;
    string roomName;
    
    void GetWorldPosition(Room targetRoom, float& out worldX, float& out worldY, float& out worldZ)
    {
        if(targetRoom == NULL) 
        {
            worldX = localX; worldY = localY; worldZ = localZ;
            return;
        }
        TFormRoom(targetRoom, localX, localY, localZ, worldX, worldY, worldZ);
    }
    
    array<Room> GetMatchingRooms()
    {
        array<Room> matches;
        for(int i = 0; i < MAX_ROOMS; i++)
        {
            Room r = world.GetRoomByIndex(i);
            if(r != NULL && r.GetIdentifier() == roomIdentifier)
                matches.push_back(r);
        }
        return matches;
    }
}

class CameraSystem
{
    CameraSystem()
    {
        currentRoom = NULL; active = false;
        camYaw = 0.0; camPitch = 0.0;
        origX = 0.0; origY = 0.0; origZ = 0.0;
        origYaw = 0.0; origPitch = 0.0;
        origRoom = NULL; camIndex = 0;
        roomCams.resize(0);
    }
    
    Room currentRoom;
    bool active;
    float camYaw, camPitch;
    float origX, origY, origZ;
    float origYaw, origPitch;
    Room origRoom;
    int camIndex;
    array<CustomCamera> roomCams;
    
    void StartCamera(Player player, Room targetRoom)
    {
        if(player == NULL || targetRoom == NULL) return;
        
        Entity playerEnt = player.GetEntity();
        if(playerEnt == NULL) return;
        
        if(!active)
        {
            origX = playerEnt.PositionX();
            origY = playerEnt.PositionY();
            origZ = playerEnt.PositionZ();
            origPitch = playerEnt.Pitch();
            origYaw = playerEnt.Yaw();
            origRoom = player.GetRoom();
            
            if(origRoom == NULL)
                origRoom = targetRoom;
        }
        
        currentRoom = targetRoom;
        active = true;
        roomCams = SCP079Cameras::GetCamerasInRoom(targetRoom.GetIndex());
        camIndex = 0;
        
        if(roomCams.size() > 0)
        {
            SwitchToCamera(player, 0);
            
            SCP079HUD::OnCameraStarted(player, targetRoom.GetName(), roomCams.size());
        }
        else
        {
            Entity roomEnt = targetRoom.GetEntity();
            if(roomEnt != NULL)
            {
                float roomX = roomEnt.PositionX();
                float roomY = roomEnt.PositionY() + 100.0;
                float roomZ = roomEnt.PositionZ();
                
                player.SetInvisible(true);
                player.Desync(true);
                player.SetPosition(roomX, roomY, roomZ, targetRoom);
                
                camYaw = 0.0;
                camPitch = -15.0;
                player.SetRotation(camPitch, camYaw);
                
                SCP079HUD::OnCameraStarted(player, targetRoom.GetName(), 1);
            }
        }
    }
    
    void SwitchToCamera(Player player, int idx)
    {
        if(player == NULL || !active || currentRoom == NULL) return;
        if(idx < 0 || idx >= roomCams.size()) return;
        
        camIndex = idx;
        CustomCamera selectedCam = roomCams[idx];
        
        float worldX, worldY, worldZ;
        selectedCam.GetWorldPosition(currentRoom, worldX, worldY, worldZ);
        
        player.SetInvisible(true);
        player.Desync(true);
        player.SetPosition(worldX, worldY, worldZ, currentRoom);
        
        camYaw = selectedCam.yaw;
        camPitch = selectedCam.pitch;
        player.SetRotation(camPitch, camYaw);
        
        if(currentRoom != NULL)
        {
            SCP079HUD::OnCameraSwitched(player, currentRoom.GetName(), camIndex, roomCams.size());
        }
    }
    
    void SwitchToNextCamera(Player player)
    {
        if(player == NULL || !active || roomCams.size() <= 1) return;
        
        int nextIdx = (camIndex + 1) % roomCams.size();
        SwitchToCamera(player, nextIdx);
    }
    
    void SwitchToPreviousCamera(Player player)
    {
        if(player == NULL || !active || roomCams.size() <= 1) return;
        
        int prevIdx = (camIndex - 1 + roomCams.size()) % roomCams.size();
        SwitchToCamera(player, prevIdx);
    }
    
    void StopCamera(Player player)
    {
        if(player == NULL || !active) return;
        
        active = false;
        player.SetInvisible(false);
        player.Desync(false);
        
        if(origRoom != NULL)
        {
            player.SetPosition(origX, origY, origZ, origRoom);
            player.SetRotation(origPitch, origYaw);
        }
        
        currentRoom = NULL;
        
        SCP079HUD::OnCameraStopped(player);
    }
    
    void UpdateCamera(Player player, float deltaYaw, float deltaPitch)
    {
        if(player == NULL || !active) return;
        
        camYaw += deltaYaw * 0.5;
        camPitch += deltaPitch * 0.5;
        
        if(camPitch > 89.0) camPitch = 89.0;
        if(camPitch < -89.0) camPitch = -89.0;
        
        while(camYaw > 180.0) camYaw -= 360.0;
        while(camYaw < -180.0) camYaw += 360.0;
        
        player.SetRotation(camPitch, camYaw);
    }
}

array<CustomCamera> g_CustomCameras;

namespace SCP079Cameras
{
    const string CAMERAS_FILE = "scp079_cameras.txt";
    const string CAMERAS_DIR = "scp079";
    filesystem@ FileSystem = filesystem();
    
    array<CameraSystem> playerCams(MAX_PLAYERS + 1);
    
    void Initialize()
    {
        SCP079Doors::Initialize();
    }
    
    void LoadCameras()
    {
        g_CustomCameras.resize(0);
        FileSystem.makeDir(CAMERAS_DIR);
        
        file f;
        if(f.open(CAMERAS_DIR + "/" + CAMERAS_FILE, "r") >= 0)
        {
            while(!f.isEndOfFile()) 
            {
                string line = f.readLine().trim();
                if(line.length() == 0 || line.substr(0, 1) == "#") continue;
                
                array<string>@ values = line.split(",");
                if(values.size() >= 7) 
                {
                    float x = parseFloat(values[0].trim());
                    float y = parseFloat(values[1].trim());
                    float z = parseFloat(values[2].trim());
                    float pitch = parseFloat(values[3].trim());
                    float yaw = parseFloat(values[4].trim());
                    int roomId = parseInt(values[5].trim());
                    
                    string roomName = "";
                    for(int i = 6; i < values.size(); i++)
                    {
                        if(i > 6) roomName += ",";
                        roomName += values[i].trim();
                    }
                    
                    CustomCamera newCam = CustomCamera(x, y, z, pitch, yaw, roomId, roomName);
                    g_CustomCameras.push_back(newCam);
                }
            }
            f.close();
        }
    }
    
    void SaveCameras()
    {
        FileSystem.makeDir(CAMERAS_DIR);
        
        file f;
        if(f.open(CAMERAS_DIR + "/" + CAMERAS_FILE, "w") >= 0)
        {
            f.writeString("# SCP-079 Custom Cameras Data File\n");
            f.writeString("# Format: localX,localY,localZ,pitch,yaw,roomIdentifier,roomName\n");
            f.writeString("# Coordinates are room-relative for map generation independence\n\n");
            
            for(int i = 0; i < g_CustomCameras.size(); i++)
            {
                CustomCamera cam = g_CustomCameras[i];
                string line = formatFloat(cam.localX, "", 0, 3) + "," +
                             formatFloat(cam.localY, "", 0, 3) + "," +
                             formatFloat(cam.localZ, "", 0, 3) + "," +
                             formatFloat(cam.pitch, "", 0, 3) + "," +
                             formatFloat(cam.yaw, "", 0, 3) + "," +
                             formatInt(cam.roomIdentifier) + "," +
                             cam.roomName + "\n";
                f.writeString(line);
            }
            
            f.close();
        }
    }
    
    void AddCamera(float playerX, float playerY, float playerZ, float pitch, float yaw, int roomIndex, const string& in roomName)
    {
        Room room = world.GetRoomByIndex(roomIndex);
        if(room == NULL) return;
        
        int roomIdentifier = room.GetIdentifier();
        Entity roomEnt = room.GetEntity();
        if(roomEnt == NULL) return;
        
        float roomWorldX = roomEnt.PositionX();
        float roomWorldY = roomEnt.PositionY();
        float roomWorldZ = roomEnt.PositionZ();
        
        float roomRelX = (playerX - roomWorldX) * 0.1;
        float roomRelY = (playerY - roomWorldY) * 0.1;
        float roomRelZ = (playerZ - roomWorldZ) * 0.1;
        
        CustomCamera newCam = CustomCamera(roomRelX, roomRelY, roomRelZ, pitch, yaw, roomIdentifier, roomName);
        g_CustomCameras.push_back(newCam);
        
        SaveCameras();
    }
    
    void RemoveCamera(int index)
    {
        if(index >= 0 && index < g_CustomCameras.size())
        {
            g_CustomCameras.removeAt(index);
            SaveCameras();
        }
    }
    
    void RemoveCamerasInRoom(int roomIndex)
    {
        Room room = world.GetRoomByIndex(roomIndex);
        if(room == NULL) return;
        
        int roomIdentifier = room.GetIdentifier();
        
        for(int i = g_CustomCameras.size() - 1; i >= 0; i--)
        {
            if(g_CustomCameras[i].roomIdentifier == roomIdentifier)
            {
                g_CustomCameras.removeAt(i);
            }
        }
        SaveCameras();
    }
    
    array<CustomCamera> GetCamerasInRoom(int roomIndex)
    {
        array<CustomCamera> roomCams;
        
        Room room = world.GetRoomByIndex(roomIndex);
        if(room == NULL) return roomCams;
        
        int roomIdentifier = room.GetIdentifier();
        
        for(int i = 0; i < g_CustomCameras.size(); i++)
        {
            if(g_CustomCameras[i].roomIdentifier == roomIdentifier)
            {
                roomCams.push_back(g_CustomCameras[i]);
            }
        }
        
        return roomCams;
    }
    
    bool HasCameraInRoom(int roomIdentifier)
    {
        for(int i = 0; i < g_CustomCameras.size(); i++)
        {
            if(g_CustomCameras[i].roomIdentifier == roomIdentifier)
                return true;
        }
        return false;
    }
    
    Room GetRandomRoomWithCamera()
    {
        if(g_CustomCameras.size() == 0) return NULL;
        
        array<int> roomIdsWithCams;
        
        for(int i = 0; i < g_CustomCameras.size(); i++)
        {
            int roomId = g_CustomCameras[i].roomIdentifier;
            bool alreadyAdded = false;
            
            for(int j = 0; j < roomIdsWithCams.size(); j++)
            {
                if(roomIdsWithCams[j] == roomId)
                {
                    alreadyAdded = true;
                    break;
                }
            }
            
            if(!alreadyAdded)
            {
                roomIdsWithCams.push_back(roomId);
            }
        }
        
        if(roomIdsWithCams.size() == 0) return NULL;
        
        int randomIdx = rand(0, roomIdsWithCams.size() - 1);
        int selectedRoomId = roomIdsWithCams[randomIdx];
        
        for(int i = 0; i < MAX_ROOMS; i++)
        {
            Room r = world.GetRoomByIndex(i);
            if(r != NULL && r.GetIdentifier() == selectedRoomId)
            {
                return r;
            }
        }
        
        return NULL;
    }
    
    void StartCameraInRoom(Player player, Room targetRoom)
    {
        if(player == NULL || targetRoom == NULL) return;
        
        int idx = player.GetIndex();
        if(idx < 0 || idx >= playerCams.size()) return;
        
        playerCams[idx].StartCamera(player, targetRoom);
    }
    
    void StopCameraForPlayer(Player player)
    {
        if(player == NULL) return;
        
        int idx = player.GetIndex();
        if(idx < 0 || idx >= playerCams.size()) return;
        
        playerCams[idx].StopCamera(player);
        
        SCP079Doors::RemoveDoorHighlighting(player);
    }
    
    bool IsPlayerInCameraMode(Player player)
    {
        if(player == NULL) return false;
        
        int idx = player.GetIndex();
        if(idx < 0 || idx >= playerCams.size()) return false;
        
        return playerCams[idx].active;
    }
    
    void SwitchToNextCameraInRoom(Player player)
    {
        if(player == NULL) return;
        
        int idx = player.GetIndex();
        if(idx < 0 || idx >= playerCams.size()) return;
        
        playerCams[idx].SwitchToNextCamera(player);
    }
    
    void SwitchToPreviousCameraInRoom(Player player)
    {
        if(player == NULL) return;
        
        int idx = player.GetIndex();
        if(idx < 0 || idx >= playerCams.size()) return;
        
        playerCams[idx].SwitchToPreviousCamera(player);
    }
    
        
    void OnPlayerUpdate(Player player)
    {
        if(player == NULL || !SCP079Base::IsSCP079Player(player)) return;
        
        if(IsPlayerInCameraMode(player))
        {
            player.SetInvisible(true);
            player.Desync(true);
            
            SCP079Doors::UpdateDoorHighlighting(player);
        }
    }
    
    void OnPlayerKeyAction(Player player, int newKeys, int prevKeys)
    {
        if(player == NULL || !SCP079Base::IsSCP079Player(player)) return;
        
        if(IsKeyPressed(KEY_N, newKeys, prevKeys))
        {
            if(IsPlayerInCameraMode(player))
            {
                SwitchToNextCameraInRoom(player);
            }
        }
        
        SCP079Doors::OnPlayerKeyAction(player, newKeys, prevKeys);
    }
    
    void OnPlayerDisconnect(Player player)
    {
        if(player == NULL) return;
        
        SCP079Doors::OnPlayerDisconnect(player);
    }
    
    int GetCameraCount()
    {
        return g_CustomCameras.size();
    }
    
    Room GetCurrentViewingRoom(Player player)
    {
        if(player == NULL) return NULL;
        
        int idx = player.GetIndex();
        if(idx < 0 || idx >= playerCams.size()) return NULL;
        
        if(!playerCams[idx].active) return NULL;
        
        return playerCams[idx].currentRoom;
    }
    
    void ListAllCameras(Player player)
    {
        if(player == NULL) return;
        
        if(g_CustomCameras.size() == 0)
        {
            SCP079Base::ShowMessage(player, "No custom cameras have been placed", 5.0);
            return;
        }
        
        SCP079Base::ShowMessage(player, "Custom Cameras (" + g_CustomCameras.size() + " total)", 5.0);
        
        for(int i = 0; i < g_CustomCameras.size() && i < 5; i++)
        {
            CustomCamera cam = g_CustomCameras[i];
            string msg = formatInt(i + 1) + ". " + GetShortRoomName(cam.roomName) + 
                           " (local: " + formatFloat(cam.localX, "", 0, 1) + ", " + 
                           formatFloat(cam.localY, "", 0, 1) + ", " + 
                           formatFloat(cam.localZ, "", 0, 1) + ")";
            SCP079Base::ShowMessage(player, msg, 5.0);
        }
    }
}
