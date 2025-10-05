#include "../include/uerm.as"
#include "../virtualmap/virtualmap_GUI.as"
#include "scp079_base.as"
#include "scp079_cameras.as"

namespace SCP079Map
{
    const int UI_UPDATE_INTERVAL = 200;
    
    void Initialize()
    {
        VirtualMapGUI::Initialize();
        
        VirtualMapGUI::SetOnRoomClickCallback(OnRoomClickHandler);
        VirtualMapGUI::SetOnMapCloseCallback(OnMapCloseHandler);
        VirtualMapGUI::SetHasCameraInRoomCallback(HasCameraInRoomHandler);
        VirtualMapGUI::SetGetCamerasInRoomCallback(GetCamerasInRoomHandler);
        VirtualMapGUI::SetGetCameraCountCallback(GetCameraCountHandler);
        VirtualMapGUI::SetGetCurrentViewingRoomCallback(GetCurrentViewingRoomHandler);
    }
    
    void OnWorldLoaded()
    {
        CreateTimer(InitializeMapSystems, 3000, false);
        CreateTimer(UpdateMapUI, UI_UPDATE_INTERVAL, true);
    }
    
    void InitializeMapSystems()
    {
        if(!IsVirtualMapReady())
        {
            CreateTimer(InitializeMapSystems, 1000, false);
            return;
        }
    }

    void UpdateMapUI()
    {
        VirtualMapGUI::UpdateHoverDetection();

        for(int i = 0; i < connPlayers.size(); i++)
        {
            Player player = connPlayers[i];
            if(player == NULL || player.IsDead()) continue;
            
            if(!SCP079Base::IsSCP079Player(player) || !VirtualMapGUI::IsMapOpen(player)) continue;
        }
    }

    void OnPlayerConnect(Player player)
    {
        if(player == NULL) return;
        UpdatePlayerRoomTracking(player);
    }
    
    void ToggleVirtualMap(Player player)
    {
        if(player == NULL) return;
        
        if(!IsVirtualMapReady())
        {
            SCP079Base::ShowMessage(player, "Virtual map not ready yet...", 3.0);
            return;
        }
        
        VirtualMapGUI::ToggleMap(player);
    }
    
    void ShowVirtualMap(Player player)
    {
        if(player == NULL) return;
        if(!IsVirtualMapReady())
        {
            SCP079Base::ShowMessage(player, "Virtual map not ready yet...", 3.0);
            return;
        }
        
        VirtualMapGUI::ShowMap(player);
    }
    
    void CloseVirtualMap(Player player)
    {
        if(player == NULL) return;
        VirtualMapGUI::CloseMap(player);
    }
    
    void OnRoomClickHandler(Player player, int roomIndex)
    {
        if(player == NULL) return;
        
        VirtualMap@ vMap = GetVirtualMap();
        if(@vMap == null || roomIndex < 0 || roomIndex >= vMap.GetRoomCount()) return;
        
        VirtualRoom@ vRoom = @vMap.rooms[roomIndex];
        if(@vRoom == null) return;
        
        bool hasCam = SCP079Cameras::HasCameraInRoom(vRoom.roomIdentifier);
        
        if(hasCam)
        {
            SCP079Cameras::StartCameraInRoom(player, vRoom.room);
            CloseVirtualMap(player);
        }
        else
        {
            string shortRoomName = vRoom.GetShortName();
            SCP079Base::ShowMessage(player, "No cameras available in " + shortRoomName, 3.0);
        }
    }
    
    void OnMapCloseHandler(Player player)
    {
    }
    
    bool HasCameraInRoomHandler(int roomIdentifier)
    {
        return SCP079Cameras::HasCameraInRoom(roomIdentifier);
    }
    
    array<string> GetCamerasInRoomHandler(int roomIndex)
    {
        array<string> camInfo;
        array<CustomCamera> cams = SCP079Cameras::GetCamerasInRoom(roomIndex);
        
        for(int i = 0; i < cams.size(); i++)
        {
            camInfo.push_back("Camera " + formatInt(i + 1));
        }
        
        return camInfo;
    }
    
    int GetCameraCountHandler()
    {
        return SCP079Cameras::GetCameraCount();
    }
    
    Room GetCurrentViewingRoomHandler(Player player)
    {
        return SCP079Cameras::GetCurrentViewingRoom(player);
    }
    
    void UpdateHoverDetection()
    {
        VirtualMapGUI::UpdateHoverDetection();
    }
    
    void OnPlayerKeyAction(Player player, int newKeys, int prevKeys)
    {
        if(player == NULL || !SCP079Base::IsSCP079Player(player)) return;
        
        if(IsKeyPressed(KEY_M, newKeys, prevKeys))
        {
            ToggleVirtualMap(player);
        }
    }
    
    void OnPlayerDisconnect(Player player)
    {
        if(player == NULL) return;
        VirtualMapGUI::OnPlayerDisconnect(player);
    }
    
    bool IsMapOpen(Player player)
    {
        return VirtualMapGUI::IsMapOpen(player);
    }
    
    void SwitchZoneView(Player player)
    {
        if(player == NULL) return;
        
        MapZoneView currentView = VirtualMapGUI::GetCurrentZoneView(player);
        MapZoneView newView = currentView;
        
        if(currentView == ZONE_VIEW_LCZ_HCZ)
        {
            newView = ZONE_VIEW_HCZ_EZ;
        }
        else
        {
            newView = ZONE_VIEW_LCZ_HCZ;
        }
        
        VirtualMapGUI::SwitchZoneView(player, newView);
        
        string newZoneText = VirtualMapGUI::GetCurrentZoneViewText(newView);
        SCP079Base::ShowMessage(player, "Switched to zone view: " + newZoneText, 2.0);
    }
    
    void AutoSwitchZoneBasedOnPlayerLocation(Player player)
    {
        if(player == NULL) return;
        
        Room currentRoom = player.GetRoom();
        if(currentRoom == NULL) return;
        
        VirtualMap@ vMap = GetVirtualMap();
        if(@vMap == null) return;
        
        VirtualRoom@ vRoom = vMap.GetRoomByIndex(currentRoom.GetIndex());
        if(@vRoom == null) return;
        
        MapZoneView suggestedView = ZONE_VIEW_LCZ_HCZ;
        
        if(vRoom.zoneType == ZONE_EZ)
        {
            suggestedView = ZONE_VIEW_HCZ_EZ;
        }
        else if(vRoom.zoneType == ZONE_HCZ)
        {
            suggestedView = ZONE_VIEW_LCZ_HCZ;
        }
        else if(vRoom.zoneType == ZONE_LCZ)
        {
            suggestedView = ZONE_VIEW_LCZ_HCZ;
        }
        else if(vRoom.zoneType == ZONE_CHECKPOINT)
        {
            suggestedView = ZONE_VIEW_HCZ_EZ;
        }
        
        MapZoneView currentView = VirtualMapGUI::GetCurrentZoneView(player);
        
        if(currentView != suggestedView)
        {
            VirtualMapGUI::SwitchZoneView(player, suggestedView);
        }
    }
}
