#include "../include/uerm.as"
#include "scp079_base.as"
#include "scp079_hud.as"
#include "scp079_doors.as"
#include "scp079_cameras.as"
#include "scp079_map.as"

namespace SCP079
{
    void Initialize()
    {
        SCP079Base::Initialize();
        SCP079Cameras::Initialize();
        SCP079Map::Initialize();
    }
    
    void OnWorldLoaded()
    {
        CreateTimer(InitializeSCP079Systems, 3000, false);
        SCP079Map::OnWorldLoaded();
    }
    
    void InitializeSCP079Systems()
    {
        if(!IsVirtualMapReady())
        {
            CreateTimer(InitializeSCP079Systems, 1000, false);
            return;
        }
        SCP079Cameras::LoadCameras();
    }
    
    void SetupSCP079Player(Player player)
    {
        if(player == NULL) return;
        
        SCP079Base::SetupPlayer(player);
        
        Room targetRoom = SCP079Cameras::GetRandomRoomWithCamera();
        
        if(targetRoom != NULL)
        {
            SCP079Cameras::StartCameraInRoom(player, targetRoom);
            SCP079Base::ShowMessage(player, "Surveillance network online. Press M for facility map.", 8.0);
            return;
        }
        
        VirtualRoom@ fallbackRoom = GetVirtualRoomByIdentifier(r_cont1_079);
        if(@fallbackRoom == null || fallbackRoom.room == NULL)
        {
            fallbackRoom = GetRandomVirtualRoom();
        }
        
        if(@fallbackRoom != null && fallbackRoom.room != NULL)
        {
            Entity roomEnt = fallbackRoom.room.GetEntity();
            if(roomEnt != NULL)
            {
                player.SetPosition(roomEnt.PositionX(), roomEnt.PositionY() + 50.0, roomEnt.PositionZ(), fallbackRoom.room);
            }
            
            SCP079Base::ShowMessage(player, "WARNING: No cameras available. Press M to access facility map.", 8.0);
        }
        else
        {
            SCP079Base::ShowMessage(player, "ERROR: Unable to initialize surveillance systems.", 8.0);
        }
    }
    
    void OnPlayerKeyAction(Player player, int newKeys, int prevKeys)
    {
        if(player == NULL || !SCP079Base::IsSCP079Player(player)) return;
        SCP079Map::OnPlayerKeyAction(player, newKeys, prevKeys);
        SCP079Cameras::OnPlayerKeyAction(player, newKeys, prevKeys);
    }
    
    void OnPlayerUpdate(Player player)
    {
        if(player == NULL || !SCP079Base::IsSCP079Player(player)) return;
        SCP079Base::OnPlayerUpdate(player);
        SCP079Cameras::OnPlayerUpdate(player);
    }
    
    void OnPlayerDisconnect(Player player)
    {
        if(player == NULL) return;
        SCP079Base::OnPlayerDisconnect(player);
        SCP079Cameras::OnPlayerDisconnect(player);
        SCP079Map::OnPlayerDisconnect(player);
    }
    
    void UpdateHoverDetection()
    {
        SCP079Map::UpdateHoverDetection();
    }
    
    bool IsSCP079Player(Player player)
    {
        return SCP079Base::IsSCP079Player(player);
    }
    
    bool IsPlayerInCameraMode(Player player)
    {
        return SCP079Cameras::IsPlayerInCameraMode(player);
    }
    
    void StopCameraForPlayer(Player player)
    {
        SCP079Cameras::StopCameraForPlayer(player);
    }
    
    void StartCameraInRoom(Player player, Room targetRoom)
    {
        SCP079Cameras::StartCameraInRoom(player, targetRoom);
    }
    
    bool ProcessCommand(Player player, const string& in message)
    {
        if(player == NULL || message.length() == 0 || message.substr(0, 1) != "/") return false;
        
        array<string>@ args = message.split(" ");
        if(args.size() == 0) return false;
        
        string cmd = args[0].substr(1);
        
        if(cmd == "addcam" || cmd == "addcamera")
        {
            if(!player.IsAdmin() && !IsSCP079Player(player))
            {
                SCP079Base::ShowMessage(player, "ACCESS DENIED: Insufficient privileges", 5.0);
                return true;
            }
            
            Room currentRoom = player.GetRoom();
            if(currentRoom == NULL)
            {
                SCP079Base::ShowMessage(player, "ERROR: Unable to determine location", 5.0);
                return true;
            }
            
            Entity playerEnt = player.GetEntity();
            if(playerEnt == NULL)
            {
                SCP079Base::ShowMessage(player, "ERROR: Entity unavailable", 5.0);
                return true;
            }
            
            SCP079Cameras::AddCamera(playerEnt.PositionX(), playerEnt.PositionY(), playerEnt.PositionZ(), 
                                   playerEnt.Pitch(), playerEnt.Yaw(), currentRoom.GetIndex(), currentRoom.GetName());
            
            SCP079Base::ShowMessage(player, "CAMERA INSTALLED: " + GetShortRoomName(currentRoom.GetName()), 5.0);
            return true;
        }
        
        return false;
    }
}

void OnSCP079WorldLoaded()
{
    SCP079::OnWorldLoaded();
}

void OnSCP079PlayerKeyAction(Player player, int newKeys, int prevKeys)
{
    SCP079::OnPlayerKeyAction(player, newKeys, prevKeys);
}

void OnSCP079Update()
{
    SCP079::UpdateHoverDetection();
}

void OnSCP079PlayerUpdate(Player player)
{
    SCP079::OnPlayerUpdate(player);
}

void OnSCP079PlayerDisconnect(Player player)
{
    SCP079::OnPlayerDisconnect(player);
}

void SetupSCP079ForPlayer(Player player)
{
    if(player == NULL) return;
    
    int timerData = CreateTimerData();
    SetTimerHandle(timerData, player);
    CreateTimer(DelayedSCP079Setup, 1000, false, timerData);
}

void DelayedSCP079Setup(Player player)
{
    if(player == NULL) return;
    SCP079::SetupSCP079Player(player);
}

void InitializeSCP079()
{
    SCP079::Initialize();
    RegisterCallback(WorldLoaded_c, "OnSCP079WorldLoaded");
    RegisterCallback(PlayerKeyAction_c, "OnSCP079PlayerKeyAction");
    RegisterCallback(PlayerUpdate_c, "OnSCP079PlayerUpdate");
    RegisterCallback(PlayerDisconnect_c, "OnSCP079PlayerDisconnect");
    CreateTimer(OnSCP079Update, 100, true);
}

bool ProcessSCP079Command(Player player, const string& in message)
{
    return SCP079::ProcessCommand(player, message);
}
