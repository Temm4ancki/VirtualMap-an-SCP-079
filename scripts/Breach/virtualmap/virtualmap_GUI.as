#include "../include/uerm.as"
#include "virtualmap_core.as"

enum MapZoneView
{
    ZONE_VIEW_LCZ_HCZ = 0,
    ZONE_VIEW_HCZ_EZ = 1,
    ZONE_VIEW_ALL_ZONES = 2,
    ZONE_VIEW_LCZ = 3,
    ZONE_VIEW_HCZ = 4,
    ZONE_VIEW_EZ = 5
}

enum MapDisplayMode
{
    MODE_ALL_ZONES = 0,
    MODE_TWO_SECTORS = 1,
    MODE_THREE_SECTORS = 2
}

namespace VirtualMapGUI
{
    array<bool> playerMapOpen(MAX_PLAYERS + 1, false);
    array<array<GUIElement>> playerMapElements(MAX_PLAYERS + 1);
    array<int> playerHoveredRoom(MAX_PLAYERS + 1, -1);
    array<int> playerRoomNameTimer(MAX_PLAYERS + 1, 0);
    array<MapZoneView> playerCurrentZoneView(MAX_PLAYERS + 1, ZONE_VIEW_LCZ_HCZ);
    array<MapDisplayMode> playerDisplayMode(MAX_PLAYERS + 1, MODE_ALL_ZONES);
    array<int> playerLastMapRefresh(MAX_PLAYERS + 1, 0);
    
    const int ROOM_LIMIT_THRESHOLD = 100;
    const int MAP_REFRESH_INTERVAL = 10;
    
    funcdef void OnRoomClickCallback(Player, int);
    funcdef void OnMapCloseCallback(Player);
    funcdef bool HasCameraInRoomCallback(int);
    funcdef array<string> GetCamerasInRoomCallback(int);
    funcdef int GetCameraCountCallback();
    funcdef Room GetCurrentViewingRoomCallback(Player);
    
    OnRoomClickCallback@ g_OnRoomClickCallback = null;
    OnMapCloseCallback@ g_OnMapCloseCallback = null;
    HasCameraInRoomCallback@ g_HasCameraInRoomCallback = null;
    GetCamerasInRoomCallback@ g_GetCamerasInRoomCallback = null;
    GetCameraCountCallback@ g_GetCameraCountCallback = null;
    GetCurrentViewingRoomCallback@ g_GetCurrentViewingRoomCallback = null;
    
    void Initialize()
    {
        for(int i = 0; i <= MAX_PLAYERS; i++)
        {
            playerMapElements[i].resize(0);
            playerMapOpen[i] = false;
            playerHoveredRoom[i] = -1;
            playerRoomNameTimer[i] = 0;
            playerCurrentZoneView[i] = ZONE_VIEW_LCZ_HCZ;
        }
    }
    
    void SetOnRoomClickCallback(OnRoomClickCallback@ callback)
    {
        @g_OnRoomClickCallback = @callback;
    }
    
    void SetOnMapCloseCallback(OnMapCloseCallback@ callback)
    {
        @g_OnMapCloseCallback = @callback;
    }
    
    void SetHasCameraInRoomCallback(HasCameraInRoomCallback@ callback)
    {
        @g_HasCameraInRoomCallback = @callback;
    }
    
    void SetGetCamerasInRoomCallback(GetCamerasInRoomCallback@ callback)
    {
        @g_GetCamerasInRoomCallback = @callback;
    }
    
    void SetGetCameraCountCallback(GetCameraCountCallback@ callback)
    {
        @g_GetCameraCountCallback = @callback;
    }
    
    void SetGetCurrentViewingRoomCallback(GetCurrentViewingRoomCallback@ callback)
    {
        @g_GetCurrentViewingRoomCallback = @callback;
    }
    
    bool IsMapOpen(Player player)
    {
        if(player == NULL) return false;
        
        int playerIndex = player.GetIndex();
        if(playerIndex < 0 || playerIndex >= playerMapOpen.size()) return false;
        
        return playerMapOpen[playerIndex];
    }
    
    void ToggleMap(Player player)
    {
        if(player == NULL) return;
        
        int playerIndex = player.GetIndex();
        if(playerIndex < 0 || playerIndex >= playerMapOpen.size()) return;
        
        if(playerMapOpen[playerIndex])
            CloseMap(player);
        else
            ShowMap(player);
    }
    
    void ShowMap(Player player)
    {
        if(player == NULL) return;
        if(!IsVirtualMapReady()) return;
        
        int playerIndex = player.GetIndex();
        if(playerIndex < 0 || playerIndex >= playerMapOpen.size()) return;
        
        InitializePlayerDisplayMode(player);
        playerMapOpen[playerIndex] = true;
        CreateMapGUI(player);
    }
    
    void CloseMap(Player player)
    {
        if(player == NULL) return;
        
        int playerIndex = player.GetIndex();
        if(playerIndex < 0 || playerIndex >= playerMapOpen.size()) return;
        
        playerMapOpen[playerIndex] = false;
        
        for(int i = 0; i < playerMapElements[playerIndex].size(); i++)
        {
            if(playerMapElements[playerIndex][i] != NULL)
            {
                playerMapElements[playerIndex][i].Remove();
            }
        }
        
        playerMapElements[playerIndex].resize(0);
        player.HideDialog();
        
        if(@g_OnMapCloseCallback != null)
        {
            g_OnMapCloseCallback(player);
        }
    }
    
    void CreateMapGUI(Player player)
    {
        if(player == NULL) return;
        
        int playerIndex = player.GetIndex();
        if(playerIndex < 0 || playerIndex >= playerMapElements.size()) return;
        
        CloseMap(player);
        playerMapOpen[playerIndex] = true;
        
        GUIElement closeButton = graphics.CreateRect(player, 0.92, 0.02, 0.06, 0.06, false);
        closeButton.SetColor(255, 0, 0);
        closeButton.SetSelectable(true);
        closeButton.SetData("close_map");
        closeButton.SetCallback("VirtualMapGUI::OnMapGUIClick");
        playerMapElements[playerIndex].push_back(closeButton);
        
        GUIElement closeText = graphics.CreateText(player, Font_Default_Big, "X", 0.92 + 0.03, 0.02 + 0.03, true);
        closeText.SetColor(255, 255, 255);
        playerMapElements[playerIndex].push_back(closeText);
        
        string instructions = "Zone colors: Yellow=LCZ, Red=HCZ, Blue=EZ, Orange=Checkpoints | Bright=Cameras+Players | Dim=No cameras | Click for details | Double-click to access camera";
        GUIElement instructionsElement = graphics.CreateText(player, Font_Default, instructions, 0.5, 0.02, true);
        instructionsElement.SetColor(200, 200, 200);
        playerMapElements[playerIndex].push_back(instructionsElement);
        
        int totalCameras = 0;
        if(@g_GetCameraCountCallback != null)
        {
            totalCameras = g_GetCameraCountCallback();
        }
        
        int roomsWithCameras = GetRoomsWithCamerasCount();
        int playersDetected = GetTotalPlayersDetected();
        
        string stats = "Cameras: " + formatInt(totalCameras) + " | Monitored Rooms: " + formatInt(roomsWithCameras) + " | Players Detected: " + formatInt(playersDetected);
        GUIElement statsElement = graphics.CreateText(player, Font_Default, stats, 0.5, 0.05, true);
        statsElement.SetColor(255, 255, 0);
        playerMapElements[playerIndex].push_back(statsElement);
        
        CreateSectorSwitchButton(player);
        DrawVirtualRooms(player);
    }
    
    void DrawVirtualRooms(Player player)
    {
        if(player == NULL) return;
        
        int playerIndex = player.GetIndex();
        if(playerIndex < 0 || playerIndex >= playerMapElements.size()) return;
        
        VirtualMap@ vMap = GetVirtualMap();
        if(@vMap == null) return;
        
        float minX, maxX, minZ, maxZ;
        vMap.GetMapBounds(minX, maxX, minZ, maxZ);
        
        float mapWidth = maxX - minX;
        float mapHeight = maxZ - minZ;
        
        if(mapWidth == 0) mapWidth = 1;
        if(mapHeight == 0) mapHeight = 1;
        
        float mapAreaLeft = 0.15;
        float mapAreaTop = 0.15;
        float mapAreaWidth = 0.7;
        float mapAreaHeight = 0.7;
        
        array<VirtualRoom@> filteredRooms = GetFilteredRoomsForZoneView(vMap, playerCurrentZoneView[playerIndex]);
        
        float filteredMinX, filteredMaxX, filteredMinZ, filteredMaxZ;
        GetFilteredMapBounds(filteredRooms, filteredMinX, filteredMaxX, filteredMinZ, filteredMaxZ);
        
        float filteredMapWidth = filteredMaxX - filteredMinX;
        float filteredMapHeight = filteredMaxZ - filteredMinZ;
        
        if(filteredMapWidth == 0) filteredMapWidth = 1;
        if(filteredMapHeight == 0) filteredMapHeight = 1;
        
        for(int i = 0; i < filteredRooms.size(); i++)
        {
            VirtualRoom@ vRoom = @filteredRooms[i];
            if(@vRoom == null) continue;
            
            int originalIndex = GetOriginalRoomIndex(vMap, vRoom);
            if(originalIndex == -1) continue;
            
            float normalizedX = mapAreaLeft + ((vRoom.x - filteredMinX) / filteredMapWidth) * mapAreaWidth;
            float normalizedZ = mapAreaTop + ((vRoom.z - filteredMinZ) / filteredMapHeight) * mapAreaHeight;
            
            float roomSize = 0.02;
            
            GUIElement roomRect = graphics.CreateRect(player, normalizedX, normalizedZ, roomSize, roomSize, false);
            roomRect.SetSelectable(true);
            roomRect.SetData("room_" + formatInt(originalIndex));
            roomRect.SetCallback("VirtualMapGUI::OnRoomClick");
            
            bool hasCamera = false;
            if(@g_HasCameraInRoomCallback != null)
            {
                hasCamera = g_HasCameraInRoomCallback(vRoom.roomIdentifier);
            }
            
            RoomScanData@ scanData = GetDelayedRoomScanDataForSCP079(vRoom.roomIndex);
            bool hasPlayers = false;
            if(scanData !is null && scanData.hasPlayers)
            {
                bool hasValidPlayers = false;
                for(int j = 0; j < g_PlayerTracking.size(); j++)
                {
                    PlayerTrackingData@ tracking = @g_PlayerTracking[j];
                    if(@tracking == null || !tracking.isValid) continue;
                    if(tracking.currentRoomIndex != vRoom.roomIndex) continue;
                    
                    Player p = GetPlayer(j);
                    if(p != NULL && !p.IsDead())
                    {
                        info_Player@ playerInfo = GetPlayerInfo(p);
                        if(@playerInfo != null && @playerInfo.pClass != null && playerInfo.pClass.roleid == ROLE_SCP_079)
                            continue;
                        
                        hasValidPlayers = true;
                        break;
                    }
                }
                hasPlayers = hasValidPlayers;
            }
            
            Room currentViewingRoom = NULL;
            if(@g_GetCurrentViewingRoomCallback != null)
            {
                currentViewingRoom = g_GetCurrentViewingRoomCallback(player);
            }
            
            bool isCurrentlyViewing = false;
            if(currentViewingRoom != NULL && vRoom.room != NULL)
            {
                isCurrentlyViewing = (currentViewingRoom.GetIndex() == vRoom.room.GetIndex());
            }
            
            int r, g, b;
            
            if(isCurrentlyViewing)
            {
                r = COLOR_CURRENT_VIEWING_ROOM[0];
                g = COLOR_CURRENT_VIEWING_ROOM[1];
                b = COLOR_CURRENT_VIEWING_ROOM[2];
            }
            else if(!hasCamera)
            {
                r = 255;
                g = 255;
                b = 255;
                
                if(!hasPlayers)
                {
                    r = int(float(r) * COLOR_MULTIPLIER_EMPTY_NO_CAMERA);
                    g = int(float(g) * COLOR_MULTIPLIER_EMPTY_NO_CAMERA);
                    b = int(float(b) * COLOR_MULTIPLIER_EMPTY_NO_CAMERA);
                }
            }
            else
            {
                GetZoneColor(vRoom.zoneType, r, g, b);
                
                if(hasPlayers)
                {
                    r = int(min(255.0, float(r) * COLOR_MULTIPLIER_CAMERA_AND_PLAYERS));
                    g = int(min(255.0, float(g) * COLOR_MULTIPLIER_CAMERA_AND_PLAYERS));
                    b = int(min(255.0, float(b) * COLOR_MULTIPLIER_CAMERA_AND_PLAYERS));
                }
                else
                {
                    r = int(float(r) * COLOR_MULTIPLIER_EMPTY_NO_CAMERA);
                    g = int(float(g) * COLOR_MULTIPLIER_EMPTY_NO_CAMERA);
                    b = int(float(b) * COLOR_MULTIPLIER_EMPTY_NO_CAMERA);
                }
            }
            
            roomRect.SetColor(r, g, b);
            
            playerMapElements[playerIndex].push_back(roomRect);
        }
    }
    
    int GetRoomsWithCamerasCount()
    {
        if(@g_GetCamerasInRoomCallback == null) return 0;
        
        array<int> uniqueRoomIds;
        VirtualMap@ vMap = GetVirtualMap();
        if(@vMap == null) return 0;
        
        for(int i = 0; i < vMap.GetRoomCount(); i++)
        {
            VirtualRoom@ vRoom = @vMap.rooms[i];
            if(@vRoom == null) continue;
            
            if(@g_HasCameraInRoomCallback != null && g_HasCameraInRoomCallback(vRoom.roomIdentifier))
            {
                bool found = false;
                for(int j = 0; j < uniqueRoomIds.size(); j++)
                {
                    if(uniqueRoomIds[j] == vRoom.roomIdentifier)
                    {
                        found = true;
                        break;
                    }
                }
                
                if(!found)
                {
                    uniqueRoomIds.push_back(vRoom.roomIdentifier);
                }
            }
        }
        
        return uniqueRoomIds.size();
    }
    
    int GetTotalPlayersDetected()
    {
        int totalPlayers = 0;
        
        for(int i = 0; i < g_ActiveRoomData.size(); i++)
        {
            RoomScanData@ scanData = GetDelayedRoomScanDataForSCP079(g_ActiveRoomData[i].roomIndex);
            if(scanData !is null && scanData.hasPlayers)
            {
                totalPlayers += scanData.playerCount;
            }
        }
        
        return totalPlayers;
    }
    
    void OnMapGUIClick(Player player, GUIElement gui)
    {
        if(player == NULL || gui == NULL) return;
        
        string data = gui.GetData();
        if(data == "close_map")
        {
            CloseMap(player);
        }
        else if(data == "switch_sector")
        {
            CycleSectorView(player);
        }
    }
    
    void OnRoomClick(Player player, GUIElement gui)
    {
        if(player == NULL || gui == NULL) return;
        
        int playerIndex = player.GetIndex();
        if(playerIndex < 0 || playerIndex >= playerMapElements.size()) return;
        
        string data = gui.GetData();
        
        if(data.findFirst("room_") == 0)
        {
            string indexStr = data.substr(5);
            int roomIndex = parseInt(indexStr);
            
            VirtualMap@ vMap = GetVirtualMap();
            if(@vMap == null || roomIndex < 0 || roomIndex >= vMap.GetRoomCount()) return;
            
            VirtualRoom@ vRoom = @vMap.rooms[roomIndex];
            if(@vRoom == null) return;
            
            string shortRoomName = vRoom.GetShortName();
            
            RoomScanData@ scanData = GetDelayedRoomScanDataForSCP079(vRoom.roomIndex);
            string playerInfo = "";
            string cameraInfo = "";
            
            bool hasCamera = false;
            if(@g_HasCameraInRoomCallback != null)
            {
                hasCamera = g_HasCameraInRoomCallback(vRoom.roomIdentifier);
            }
            
            if(hasCamera)
            {
                if(@g_GetCamerasInRoomCallback != null)
                {
                    array<string> cameras = g_GetCamerasInRoomCallback(vRoom.roomIndex);
                    cameraInfo = " [" + formatInt(cameras.size()) + " cameras]";
                }
                else
                {
                    cameraInfo = " [Cameras available]";
                }
            }
            else
            {
                cameraInfo = " [No cameras - Blind spot]";
            }
            
            if(scanData !is null && scanData.hasPlayers)
            {
                playerInfo = " [" + formatInt(scanData.playerCount) + " players: ";
                for(int i = 0; i < scanData.playerNames.size() && i < scanData.playerRoles.size(); i++)
                {
                    playerInfo += scanData.playerNames[i] + "(" + scanData.playerRoles[i] + ")";
                    if(i < scanData.playerNames.size() - 1) playerInfo += ", ";
                }
                playerInfo += "]";
            }
            else
            {
                if(scanData !is null)
                {
                    playerInfo = " [Empty]";
                }
                else
                {
                    playerInfo = " [No scan data]";
                }
            }
            
            if(playerHoveredRoom[playerIndex] == roomIndex)
            {
                if(@g_OnRoomClickCallback != null)
                {
                    g_OnRoomClickCallback(player, roomIndex);
                }
            }
            else
            {
                RemoveRoomNameDisplay(player);
                ShowRoomNameOnMap(player, shortRoomName, vRoom.roomName + cameraInfo + playerInfo, gui);
                playerHoveredRoom[playerIndex] = roomIndex;
                playerRoomNameTimer[playerIndex] = 50;
            }
        }
    }
    
    void ShowRoomNameOnMap(Player player, const string& in shortName, const string& in fullName, GUIElement hoveredElement)
    {
        if(player == NULL || hoveredElement == NULL) return;
        
        int playerIndex = player.GetIndex();
        if(playerIndex < 0 || playerIndex >= playerMapElements.size()) return;
        
        float roomX, roomY;
        hoveredElement.GetPosition(roomX, roomY);
        
        float nameX = roomX;
        float nameY = roomY - 0.08;
        
        if(nameY < 0.1) nameY = roomY + 0.04;
        
        GUIElement nameBackground = graphics.CreateRect(player, nameX, nameY, 0.3, 0.08, true);
        nameBackground.SetColor(0, 0, 0);
        nameBackground.SetOpacity(0.9, 0.0);
        nameBackground.SetData("room_name_display");
        playerMapElements[playerIndex].push_back(nameBackground);
        
        GUIElement shortNameText = graphics.CreateText(player, Font_Default_Big, shortName, nameX, nameY - 0.01, true);
        shortNameText.SetColor(255, 255, 0);
        shortNameText.SetData("room_name_display");
        playerMapElements[playerIndex].push_back(shortNameText);
        
        GUIElement fullNameText = graphics.CreateText(player, Font_Default, fullName, nameX, nameY + 0.025, true);
        fullNameText.SetColor(200, 200, 200);
        fullNameText.SetData("room_name_display");
        playerMapElements[playerIndex].push_back(fullNameText);
    }
    
    void RemoveRoomNameDisplay(Player player)
    {
        if(player == NULL) return;
        
        int playerIndex = player.GetIndex();
        if(playerIndex < 0 || playerIndex >= playerMapElements.size()) return;
        
        for(int i = playerMapElements[playerIndex].size() - 1; i >= 0; i--)
        {
            if(playerMapElements[playerIndex][i] != NULL)
            {
                string data = playerMapElements[playerIndex][i].GetData();
                if(data == "room_name_display")
                {
                    playerMapElements[playerIndex][i].Remove();
                    playerMapElements[playerIndex].removeAt(i);
                }
            }
        }
    }
    
    void UpdateHoverDetection()
    {
        for(int i = 0; i < connPlayers.size(); i++)
        {
            Player player = connPlayers[i];
            if(player == NULL || player.IsDead()) continue;
            
            int playerIndex = player.GetIndex();
            if(playerIndex < 0 || playerIndex >= playerMapOpen.size()) continue;
            
            if(!playerMapOpen[playerIndex]) continue;
            
            if(playerRoomNameTimer[playerIndex] > 0)
            {
                playerRoomNameTimer[playerIndex]--;
                if(playerRoomNameTimer[playerIndex] <= 0)
                {
                    RemoveRoomNameDisplay(player);
                    playerHoveredRoom[playerIndex] = -1;
                }
            }
            
            playerLastMapRefresh[playerIndex]++;
            if(playerLastMapRefresh[playerIndex] >= MAP_REFRESH_INTERVAL)
            {
                playerLastMapRefresh[playerIndex] = 0;
                RefreshMapDisplay(player);
            }
        }
    }
    
    void RefreshMapDisplay(Player player)
    {
        if(player == NULL) return;
        
        int playerIndex = player.GetIndex();
        if(playerIndex < 0 || playerIndex >= playerMapOpen.size()) return;
        
        if(!playerMapOpen[playerIndex]) return;
        
        int savedHoveredRoom = playerHoveredRoom[playerIndex];
        int savedRoomNameTimer = playerRoomNameTimer[playerIndex];
        
        VirtualMap@ vMap = GetVirtualMap();
        if(@vMap == null) return;
        
        string savedShortName = "";
        string savedFullName = "";
        float savedTooltipX = 0.0;
        float savedTooltipY = 0.0;
        bool hasTooltip = false;
        
        if(savedHoveredRoom >= 0 && savedHoveredRoom < vMap.GetRoomCount())
        {
            VirtualRoom@ vRoom = @vMap.rooms[savedHoveredRoom];
            if(@vRoom != null)
            {
                hasTooltip = true;
                savedShortName = vRoom.GetShortName();
                
                RoomScanData@ scanData = GetDelayedRoomScanDataForSCP079(vRoom.roomIndex);
                string playerInfo = "";
                string cameraInfo = "";
                
                bool hasCamera = false;
                if(@g_HasCameraInRoomCallback != null)
                {
                    hasCamera = g_HasCameraInRoomCallback(vRoom.roomIdentifier);
                }
                
                if(hasCamera)
                {
                    if(@g_GetCamerasInRoomCallback != null)
                    {
                        array<string> cameras = g_GetCamerasInRoomCallback(vRoom.roomIndex);
                        cameraInfo = " [" + formatInt(cameras.size()) + " cameras]";
                    }
                    else
                    {
                        cameraInfo = " [Cameras available]";
                    }
                }
                else
                {
                    cameraInfo = " [No cameras - Blind spot]";
                }
                
                if(scanData !is null && scanData.hasPlayers)
                {
                    playerInfo = " [" + formatInt(scanData.playerCount) + " players: ";
                    for(int i = 0; i < scanData.playerNames.size() && i < scanData.playerRoles.size(); i++)
                    {
                        playerInfo += scanData.playerNames[i] + "(" + scanData.playerRoles[i] + ")";
                        if(i < scanData.playerNames.size() - 1) playerInfo += ", ";
                    }
                    playerInfo += "]";
                }
                else
                {
                    if(scanData !is null)
                    {
                        playerInfo = " [Empty]";
                    }
                    else
                    {
                        playerInfo = " [No scan data]";
                    }
                }
                
                savedFullName = vRoom.roomName + cameraInfo + playerInfo;
            }
        }
        
        for(int i = playerMapElements[playerIndex].size() - 1; i >= 0; i--)
        {
            if(playerMapElements[playerIndex][i] != NULL)
            {
                playerMapElements[playerIndex][i].Remove();
            }
        }
        playerMapElements[playerIndex].resize(0);
        
        GUIElement closeButton = graphics.CreateRect(player, 0.92, 0.02, 0.06, 0.06, false);
        closeButton.SetColor(255, 0, 0);
        closeButton.SetSelectable(true);
        closeButton.SetData("close_map");
        closeButton.SetCallback("VirtualMapGUI::OnMapGUIClick");
        playerMapElements[playerIndex].push_back(closeButton);
        
        GUIElement closeText = graphics.CreateText(player, Font_Default_Big, "X", 0.92 + 0.03, 0.02 + 0.03, true);
        closeText.SetColor(255, 255, 255);
        playerMapElements[playerIndex].push_back(closeText);
        
        string instructions = "Zone colors: Yellow=LCZ, Red=HCZ, Blue=EZ, Orange=Checkpoints | Bright=Cameras+Players | Dim=No cameras | Click for details | Double-click to access camera";
        GUIElement instructionsElement = graphics.CreateText(player, Font_Default, instructions, 0.5, 0.02, true);
        instructionsElement.SetColor(200, 200, 200);
        playerMapElements[playerIndex].push_back(instructionsElement);
        
        int totalCameras = 0;
        if(@g_GetCameraCountCallback != null)
        {
            totalCameras = g_GetCameraCountCallback();
        }
        
        int roomsWithCameras = GetRoomsWithCamerasCount();
        int playersDetected = GetTotalPlayersDetected();
        
        string stats = "Cameras: " + formatInt(totalCameras) + " | Monitored Rooms: " + formatInt(roomsWithCameras) + " | Players Detected: " + formatInt(playersDetected);
        GUIElement statsElement = graphics.CreateText(player, Font_Default, stats, 0.5, 0.05, true);
        statsElement.SetColor(255, 255, 0);
        playerMapElements[playerIndex].push_back(statsElement);
        
        CreateSectorSwitchButton(player);
        DrawVirtualRooms(player);
        
        if(hasTooltip && savedRoomNameTimer > 0)
        {
            array<VirtualRoom@> filteredRooms = GetFilteredRoomsForZoneView(vMap, playerCurrentZoneView[playerIndex]);
            
            float filteredMinX, filteredMaxX, filteredMinZ, filteredMaxZ;
            GetFilteredMapBounds(filteredRooms, filteredMinX, filteredMaxX, filteredMinZ, filteredMaxZ);
            
            float filteredMapWidth = filteredMaxX - filteredMinX;
            float filteredMapHeight = filteredMaxZ - filteredMinZ;
            
            if(filteredMapWidth == 0) filteredMapWidth = 1;
            if(filteredMapHeight == 0) filteredMapHeight = 1;
            
            VirtualRoom@ vRoom = @vMap.rooms[savedHoveredRoom];
            if(@vRoom != null)
            {
                float mapAreaLeft = 0.15;
                float mapAreaTop = 0.15;
                float mapAreaWidth = 0.7;
                float mapAreaHeight = 0.7;
                
                float normalizedX = mapAreaLeft + ((vRoom.x - filteredMinX) / filteredMapWidth) * mapAreaWidth;
                float normalizedZ = mapAreaTop + ((vRoom.z - filteredMinZ) / filteredMapHeight) * mapAreaHeight;
                
                float nameX = normalizedX;
                float nameY = normalizedZ - 0.08;
                
                if(nameY < 0.1) nameY = normalizedZ + 0.04;
                
                GUIElement nameBackground = graphics.CreateRect(player, nameX, nameY, 0.3, 0.08, true);
                nameBackground.SetColor(0, 0, 0);
                nameBackground.SetOpacity(0.9, 0.0);
                nameBackground.SetData("room_name_display");
                playerMapElements[playerIndex].push_back(nameBackground);
                
                GUIElement shortNameText = graphics.CreateText(player, Font_Default_Big, savedShortName, nameX, nameY - 0.01, true);
                shortNameText.SetColor(255, 255, 0);
                shortNameText.SetData("room_name_display");
                playerMapElements[playerIndex].push_back(shortNameText);
                
                GUIElement fullNameText = graphics.CreateText(player, Font_Default, savedFullName, nameX, nameY + 0.025, true);
                fullNameText.SetColor(200, 200, 200);
                fullNameText.SetData("room_name_display");
                playerMapElements[playerIndex].push_back(fullNameText);
            }
        }
        
        playerHoveredRoom[playerIndex] = savedHoveredRoom;
        playerRoomNameTimer[playerIndex] = savedRoomNameTimer;
    }
    
    void OnPlayerDisconnect(Player player)
    {
        if(player == NULL) return;
        CloseMap(player);
    }
    
    void SwitchZoneView(Player player, MapZoneView newView)
    {
        if(player == NULL) return;
        
        int playerIndex = player.GetIndex();
        if(playerIndex < 0 || playerIndex >= playerCurrentZoneView.size()) return;
        
        playerCurrentZoneView[playerIndex] = newView;
        
        if(playerMapOpen[playerIndex])
        {
            CreateMapGUI(player);
        }
    }
    
    MapZoneView GetCurrentZoneView(Player player)
    {
        if(player == NULL) return ZONE_VIEW_LCZ_HCZ;
        
        int playerIndex = player.GetIndex();
        if(playerIndex < 0 || playerIndex >= playerCurrentZoneView.size()) return ZONE_VIEW_LCZ_HCZ;
        
        return playerCurrentZoneView[playerIndex];
    }
    
    string GetCurrentZoneViewText(MapZoneView zoneView)
    {
        switch(zoneView)
        {
            case ZONE_VIEW_LCZ_HCZ:
                return "LCZ + HCZ";
            case ZONE_VIEW_HCZ_EZ:
                return "HCZ + EZ";
            case ZONE_VIEW_ALL_ZONES:
                return "All Zones";
            case ZONE_VIEW_LCZ:
                return "LCZ Only";
            case ZONE_VIEW_HCZ:
                return "HCZ Only";
            case ZONE_VIEW_EZ:
                return "EZ Only";
            default:
                return "Unknown";
        }
    }
    
    array<VirtualRoom@> GetFilteredRoomsForZoneView(VirtualMap@ vMap, MapZoneView zoneView)
    {
        array<VirtualRoom@> filteredRooms;
        
        if(@vMap == null) return filteredRooms;
        
        for(int i = 0; i < vMap.GetRoomCount(); i++)
        {
            VirtualRoom@ vRoom = @vMap.rooms[i];
            if(@vRoom == null) continue;
            
            bool includeRoom = false;
            
            switch(zoneView)
            {
                case ZONE_VIEW_ALL_ZONES:
                    includeRoom = true;
                    break;
                    
                case ZONE_VIEW_LCZ_HCZ:
                    includeRoom = (vRoom.zoneType == ZONE_LCZ || 
                                 vRoom.zoneType == ZONE_HCZ || 
                                 vRoom.zoneType == ZONE_CHECKPOINT);
                    break;
                    
                case ZONE_VIEW_HCZ_EZ:
                    includeRoom = (vRoom.zoneType == ZONE_HCZ || 
                                 vRoom.zoneType == ZONE_EZ || 
                                 vRoom.zoneType == ZONE_CHECKPOINT ||
                                 vRoom.zoneType == ZONE_SURFACE);
                    break;
                    
                case ZONE_VIEW_LCZ:
                    includeRoom = (vRoom.zoneType == ZONE_LCZ);
                    if(!includeRoom && vRoom.zoneType == ZONE_CHECKPOINT)
                    {
                        includeRoom = IsLCZHCZCheckpoint(vRoom);
                    }
                    break;
                    
                case ZONE_VIEW_HCZ:
                    includeRoom = (vRoom.zoneType == ZONE_HCZ || 
                                 vRoom.zoneType == ZONE_CHECKPOINT);
                    break;
                    
                case ZONE_VIEW_EZ:
                    includeRoom = (vRoom.zoneType == ZONE_EZ || 
                                 vRoom.zoneType == ZONE_SURFACE);
                    if(!includeRoom && vRoom.zoneType == ZONE_CHECKPOINT)
                    {
                        includeRoom = IsHCZEZCheckpoint(vRoom);
                    }
                    break;
            }
            
            if(includeRoom)
            {
                filteredRooms.push_back(@vRoom);
            }
        }
        
        return filteredRooms;
    }
    
    void GetFilteredMapBounds(array<VirtualRoom@>& filteredRooms, float& out minX, float& out maxX, float& out minZ, float& out maxZ)
    {
        if(filteredRooms.size() == 0)
        {
            minX = maxX = minZ = maxZ = 0.0;
            return;
        }
        
        minX = maxX = filteredRooms[0].x;
        minZ = maxZ = filteredRooms[0].z;
        
        for(int i = 1; i < filteredRooms.size(); i++)
        {
            VirtualRoom@ vRoom = @filteredRooms[i];
            if(@vRoom == null) continue;
            
            if(vRoom.x < minX) minX = vRoom.x;
            if(vRoom.x > maxX) maxX = vRoom.x;
            if(vRoom.z < minZ) minZ = vRoom.z;
            if(vRoom.z > maxZ) maxZ = vRoom.z;
        }
    }
    
    int GetOriginalRoomIndex(VirtualMap@ vMap, VirtualRoom@ targetRoom)
    {
        if(@vMap == null || @targetRoom == null) return -1;
        
        for(int i = 0; i < vMap.GetRoomCount(); i++)
        {
            VirtualRoom@ vRoom = @vMap.rooms[i];
            if(@vRoom == null) continue;
            
            if(vRoom.roomIndex == targetRoom.roomIndex && 
               vRoom.roomIdentifier == targetRoom.roomIdentifier)
            {
                return i;
            }
        }
        
        return -1;
    }
    
    bool IsZoneTransitionCheckpoint(VirtualRoom@ room)
    {
        if(@room == null) return false;
        
        if(room.roomIdentifier == r_room2_checkpoint_lcz_hcz || 
           room.roomIdentifier == r_room2_checkpoint_hcz_ez)
        {
            return true;
        }
        
        string roomName = room.roomName;
        if((roomName.findFirst("lcz") >= 0 && roomName.findFirst("hcz") >= 0) ||
           (roomName.findFirst("hcz") >= 0 && roomName.findFirst("ez") >= 0))
        {
            return true;
        }
        
        return false;
    }
    
    bool ShouldSwitchZoneOnCheckpointClick(Player player, VirtualRoom@ room)
    {
        if(player == NULL || @room == null) return false;
        
        int playerIndex = player.GetIndex();
        if(playerIndex < 0 || playerIndex >= playerCurrentZoneView.size()) return false;
        
        if(!IsZoneTransitionCheckpoint(room)) return false;
        
        MapZoneView currentView = playerCurrentZoneView[playerIndex];
        
        if(room.roomIdentifier == r_room2_checkpoint_lcz_hcz)
        {
            return (currentView == ZONE_VIEW_HCZ_EZ);
        }
        else if(room.roomIdentifier == r_room2_checkpoint_hcz_ez)
        {
            return (currentView == ZONE_VIEW_LCZ_HCZ);
        }
        else
        {
            string roomName = room.roomName;
            if(roomName.findFirst("lcz") >= 0 && roomName.findFirst("hcz") >= 0)
            {
                return (currentView == ZONE_VIEW_HCZ_EZ);
            }
            else if(roomName.findFirst("hcz") >= 0 && roomName.findFirst("ez") >= 0)
            {
                return (currentView == ZONE_VIEW_LCZ_HCZ);
            }
        }
        
        return false;
    }
    
    void HandleCheckpointClick(Player player, VirtualRoom@ checkpointRoom)
    {
        if(player == NULL || @checkpointRoom == null) return;
        
        int playerIndex = player.GetIndex();
        if(playerIndex < 0 || playerIndex >= playerCurrentZoneView.size()) return;
        
        MapZoneView newZoneView = playerCurrentZoneView[playerIndex];
        
        if(checkpointRoom.roomIdentifier == r_room2_checkpoint_lcz_hcz)
        {
            newZoneView = ZONE_VIEW_LCZ_HCZ;
        }
        else if(checkpointRoom.roomIdentifier == r_room2_checkpoint_hcz_ez)
        {
            newZoneView = ZONE_VIEW_HCZ_EZ;
        }
        else
        {
            string roomName = checkpointRoom.roomName;
            if(roomName.findFirst("lcz") >= 0 && roomName.findFirst("hcz") >= 0)
            {
                newZoneView = ZONE_VIEW_LCZ_HCZ;
            }
            else if(roomName.findFirst("hcz") >= 0 && roomName.findFirst("ez") >= 0)
            {
                newZoneView = ZONE_VIEW_HCZ_EZ;
            }
        }
        
        if(playerCurrentZoneView[playerIndex] != newZoneView)
        {
            playerCurrentZoneView[playerIndex] = newZoneView;
            
            if(playerMapOpen[playerIndex])
            {
                CreateMapGUI(player);
            }
        }
    }
    
    MapDisplayMode DetermineOptimalDisplayMode(VirtualMap@ vMap)
    {
        if(@vMap == null) return MODE_ALL_ZONES;
        
        int totalRooms = vMap.GetRoomCount();
        
        if(totalRooms <= ROOM_LIMIT_THRESHOLD)
        {
            return MODE_ALL_ZONES;
        }
        
        int lczRooms = CountRoomsByZone(vMap, ZONE_LCZ);
        int hczRooms = CountRoomsByZone(vMap, ZONE_HCZ);
        int ezRooms = CountRoomsByZone(vMap, ZONE_EZ);
        int checkpointRooms = CountRoomsByZone(vMap, ZONE_CHECKPOINT);
        
        int lczHczTotal = lczRooms + hczRooms + checkpointRooms;
        int hczEzTotal = hczRooms + ezRooms + checkpointRooms;
        
        if(lczHczTotal <= ROOM_LIMIT_THRESHOLD && hczEzTotal <= ROOM_LIMIT_THRESHOLD)
        {
            return MODE_TWO_SECTORS;
        }
        
        return MODE_THREE_SECTORS;
    }
    
    int CountRoomsByZone(VirtualMap@ vMap, ZoneType zone)
    {
        if(@vMap == null) return 0;
        
        int count = 0;
        for(int i = 0; i < vMap.GetRoomCount(); i++)
        {
            VirtualRoom@ vRoom = @vMap.rooms[i];
            if(@vRoom != null && vRoom.zoneType == zone)
            {
                count++;
            }
        }
        return count;
    }
    
    void InitializePlayerDisplayMode(Player player)
    {
        if(player == NULL) return;
        
        int playerIndex = player.GetIndex();
        if(playerIndex < 0 || playerIndex >= playerDisplayMode.size()) return;
        
        VirtualMap@ vMap = GetVirtualMap();
        if(@vMap == null) return;
        
        MapDisplayMode optimalMode = DetermineOptimalDisplayMode(vMap);
        playerDisplayMode[playerIndex] = optimalMode;
        
        switch(optimalMode)
        {
            case MODE_ALL_ZONES:
                playerCurrentZoneView[playerIndex] = ZONE_VIEW_ALL_ZONES;
                break;
            case MODE_TWO_SECTORS:
                playerCurrentZoneView[playerIndex] = ZONE_VIEW_LCZ_HCZ;
                break;
            case MODE_THREE_SECTORS:
                playerCurrentZoneView[playerIndex] = ZONE_VIEW_LCZ;
                break;
        }
    }
    
    void CycleSectorView(Player player)
    {
        if(player == NULL) return;
        
        int playerIndex = player.GetIndex();
        if(playerIndex < 0 || playerIndex >= playerDisplayMode.size()) return;
        
        VirtualMap@ vMap = GetVirtualMap();
        if(@vMap == null) return;
        
        MapDisplayMode currentMode = playerDisplayMode[playerIndex];
        
        switch(currentMode)
        {
            case MODE_ALL_ZONES:
                break;
                
            case MODE_TWO_SECTORS:
                if(playerCurrentZoneView[playerIndex] == ZONE_VIEW_LCZ_HCZ)
                {
                    playerCurrentZoneView[playerIndex] = ZONE_VIEW_HCZ_EZ;
                }
                else
                {
                    playerCurrentZoneView[playerIndex] = ZONE_VIEW_LCZ_HCZ;
                }
                break;
                
            case MODE_THREE_SECTORS:
                if(playerCurrentZoneView[playerIndex] == ZONE_VIEW_LCZ)
                {
                    playerCurrentZoneView[playerIndex] = ZONE_VIEW_HCZ;
                }
                else if(playerCurrentZoneView[playerIndex] == ZONE_VIEW_HCZ)
                {
                    playerCurrentZoneView[playerIndex] = ZONE_VIEW_EZ;
                }
                else
                {
                    playerCurrentZoneView[playerIndex] = ZONE_VIEW_LCZ;
                }
                break;
        }
        
        if(playerMapOpen[playerIndex])
        {
            CreateMapGUI(player);
        }
    }
    
    void CreateSectorSwitchButton(Player player)
    {
        if(player == NULL) return;
        
        int playerIndex = player.GetIndex();
        if(playerIndex < 0 || playerIndex >= playerDisplayMode.size()) return;
        
        MapDisplayMode currentMode = playerDisplayMode[playerIndex];
        
        if(currentMode == MODE_ALL_ZONES) return;
        
        float buttonX = 0.02;
        float buttonY = 0.40;
        float buttonWidth = 0.12;
        float buttonHeight = 0.06;
        
        GUIElement switchButton = graphics.CreateRect(player, buttonX, buttonY, buttonWidth, buttonHeight, false);
        switchButton.SetColor(0, 100, 200);
        switchButton.SetSelectable(true);
        switchButton.SetData("switch_sector");
        switchButton.SetCallback("VirtualMapGUI::OnMapGUIClick");
        playerMapElements[playerIndex].push_back(switchButton);
        
        string buttonText = "Switch Sector";
        if(currentMode == MODE_THREE_SECTORS)
        {
            buttonText = "Next Zone";
        }
        
        GUIElement switchText = graphics.CreateText(player, Font_Default, buttonText, buttonX + (buttonWidth / 2.0), buttonY + (buttonHeight / 2.0), true);
        switchText.SetColor(255, 255, 255);
        playerMapElements[playerIndex].push_back(switchText);
        
        string currentZoneText = GetCurrentZoneViewText(playerCurrentZoneView[playerIndex]);
        GUIElement currentZoneDisplay = graphics.CreateText(player, Font_Default, "Current: " + currentZoneText, buttonX + (buttonWidth / 2.0), buttonY + buttonHeight + 0.01, true);
        currentZoneDisplay.SetColor(255, 255, 0);
        playerMapElements[playerIndex].push_back(currentZoneDisplay);
    }
    
    bool IsLCZHCZCheckpoint(VirtualRoom@ room)
    {
        if(@room == null) return false;
        
        if(room.roomIdentifier == r_room2_checkpoint_lcz_hcz)
        {
            return true;
        }
        
        string roomName = room.roomName;
        if(roomName.findFirst("lcz") >= 0 && roomName.findFirst("hcz") >= 0)
        {
            return true;
        }
        
        return false;
    }
    
    bool IsHCZEZCheckpoint(VirtualRoom@ room)
    {
        if(@room == null) return false;
        
        if(room.roomIdentifier == r_room2_checkpoint_hcz_ez)
        {
            return true;
        }
        
        string roomName = room.roomName;
        if(roomName.findFirst("hcz") >= 0 && roomName.findFirst("ez") >= 0)
        {
            return true;
        }
        
        return false;
    }
}
