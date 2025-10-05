#include "../include/uerm.as"
#include "scp079_base.as"

namespace SCP079HUD
{
    array<GUIElement> mainInfoDisplay(MAX_PLAYERS + 1);
    array<GUIElement> controlsDisplay(MAX_PLAYERS + 1);
    array<GUIElement> crosshairDisplay(MAX_PLAYERS + 1);
    
    array<string> cachedMainInfo(MAX_PLAYERS + 1);
    array<string> cachedCameraInfo(MAX_PLAYERS + 1);
    array<string> cachedStatusInfo(MAX_PLAYERS + 1);
    
    void Initialize()
    {
        for(int i = 0; i <= MAX_PLAYERS; i++)
        {
            mainInfoDisplay[i] = NULL;
            controlsDisplay[i] = NULL;
            crosshairDisplay[i] = NULL;
            cachedMainInfo[i] = "";
            cachedCameraInfo[i] = "";
            cachedStatusInfo[i] = "";
        }
    }
    
    bool ValidIndex(int idx)
    {
        return idx >= 0 && idx <= MAX_PLAYERS;
    }
    
    void CreateHUD(Player player)
    {
        if(player == NULL) return;
        
        int idx = player.GetIndex();
        if(!ValidIndex(idx)) return;
        
        DestroyHUD(player);
        
        GUIElement mainText = graphics.CreateText(player, Font_Default, "CAMERA: Initializing...\nSTATUS: Online\nDETECTED (0): No movement", 0.02, 0.05, false);
        if(mainText != NULL)
        {
            mainText.SetColor(0, 255, 0);
            mainInfoDisplay[idx] = mainText;
        }
        
        GUIElement ctrlText = graphics.CreateText(player, Font_Default, "M: Map | N: Next Cam | F: Use Door", 0.02, 0.85, false);
        if(ctrlText != NULL)
        {
            ctrlText.SetColor(180, 180, 180);
            controlsDisplay[idx] = ctrlText;
        }
    }
    
    void DestroyHUD(Player player)
    {
        if(player == NULL) return;
        
        int idx = player.GetIndex();
        if(!ValidIndex(idx)) return;
        
        if(mainInfoDisplay[idx] != NULL)
        {
            mainInfoDisplay[idx].Remove();
            mainInfoDisplay[idx] = NULL;
        }
        
        if(controlsDisplay[idx] != NULL)
        {
            controlsDisplay[idx].Remove();
            controlsDisplay[idx] = NULL;
        }
        
        if(crosshairDisplay[idx] != NULL)
        {
            crosshairDisplay[idx].Remove();
            crosshairDisplay[idx] = NULL;
        }
        
        cachedMainInfo[idx] = "";
        cachedCameraInfo[idx] = "";
        cachedStatusInfo[idx] = "";
    }
    
    void UpdateMainInfo(Player player, const string& in camInfo, const string& in statusInfo, const string& in detectedInfo)
    {
        if(player == NULL) return;
        
        int idx = player.GetIndex();
        if(!ValidIndex(idx)) return;
        
        string fullInfo = camInfo + "\n" + statusInfo + "\n" + detectedInfo;
        
        if(cachedMainInfo[idx] != fullInfo)
        {
            cachedMainInfo[idx] = fullInfo;
            
            if(mainInfoDisplay[idx] != NULL)
            {
                mainInfoDisplay[idx].SetText(fullInfo);
                mainInfoDisplay[idx].SetColor(0, 255, 0);
            }
        }
    }
    
    void UpdateCameraInfo(Player player, const string& in roomName, int camIdx, int totalCams)
    {
        if(player == NULL) return;
        
        int idx = player.GetIndex();
        if(!ValidIndex(idx)) return;
        
        string camInfo = "CAMERA: " + GetShortRoomName(roomName);
        
        if(totalCams > 1)
        {
            camInfo += " CAM #" + formatInt(camIdx + 1);
        }
        
        cachedCameraInfo[idx] = camInfo;
    }
    
    void UpdateHUDPeriodic(Player player)
    {
        if(player == NULL || !SCP079Base::IsSCP079Player(player)) return;
        
        int idx = player.GetIndex();
        if(!ValidIndex(idx)) return;
        
        Room currentRoom = player.GetRoom();
        string camInfo = "CAMERA: Unknown Location";
        string statusInfo = "STATUS: Location Unknown";
        string detectedInfo = "DETECTED (0): No movement";
        
        if(currentRoom != NULL)
        {
            if(cachedCameraInfo[idx] != "")
            {
                camInfo = cachedCameraInfo[idx];
            }
            else
            {
                camInfo = "CAMERA: " + GetShortRoomName(currentRoom.GetName());
            }
            
            string status = "Monitoring";
            if(SCP079Cameras::IsPlayerInCameraMode(player))
            {
                status = "Camera Active";
            }
            statusInfo = "STATUS: " + status;
            
            RoomScanData@ scanData = GetDelayedRoomScanDataForSCP079(currentRoom.GetIndex());
            
            if(scanData !is null && scanData.hasPlayers)
            {
                string detectedSubjects = "";
                int subjectCount = 0;
                
                for(int i = 0; i < scanData.playerNames.size() && i < scanData.playerRoles.size(); i++)
                {
                    string roleName = scanData.playerRoles[i];
                    
                    subjectCount++;
                    
                    if(roleName.findFirst("SCP") == 0)
                    {
                        detectedSubjects += "• " + roleName + "\n";
                    }
                    else
                    {
                        detectedSubjects += "• " + scanData.playerNames[i] + " [" + roleName + "]\n";
                    }
                }
                
                if(subjectCount > 0)
                {
                    detectedInfo = "DETECTED (" + formatInt(subjectCount) + "):\n" + detectedSubjects;
                }
                else
                {
                    detectedInfo = "DETECTED (0): No movement";
                }
            }
            else
            {
                detectedInfo = "DETECTED (0): No movement";
            }
        }
        
        UpdateMainInfo(player, camInfo, statusInfo, detectedInfo);
    }
    
    void ShowTemporaryMessage(Player player, const string& in msg, float duration = 3.0)
    {
        if(player == NULL) return;
        
        int idx = player.GetIndex();
        if(!ValidIndex(idx)) return;
        
        if(mainInfoDisplay[idx] != NULL)
        {
            Room currentRoom = player.GetRoom();
            string camInfo = cachedCameraInfo[idx];
            if(camInfo == "" && currentRoom != NULL)
            {
                camInfo = "CAMERA: " + GetShortRoomName(currentRoom.GetName());
            }
            
            string statusInfo = "STATUS: " + msg;
            string detectedInfo = "DETECTED (0): No movement";
            
            string tempInfo = camInfo + "\n" + statusInfo + "\n" + detectedInfo;
            mainInfoDisplay[idx].SetText(tempInfo);
            mainInfoDisplay[idx].SetColor(255, 255, 0);
            
            int timerData = CreateTimerData();
            SetTimerHandle(timerData, player);
            CreateTimer(RestoreMainDisplay, int(duration * 1000), false, timerData);
        }
    }
    
    void RestoreMainDisplay(Player player)
    {
        if(player == NULL) return;
        
        int idx = player.GetIndex();
        if(!ValidIndex(idx)) return;
        
        if(mainInfoDisplay[idx] != NULL)
        {
            mainInfoDisplay[idx].SetColor(0, 255, 0);
        }
    }
    
    void OnCameraSwitched(Player player, const string& in roomName, int camIdx, int totalCams)
    {
        if(player == NULL) return;
        
        UpdateCameraInfo(player, roomName, camIdx, totalCams);
        
        if(totalCams > 1)
        {
            string switchMsg = "Switched to CAM #" + formatInt(camIdx + 1);
            ShowTemporaryMessage(player, switchMsg, 2.0);
        }
    }
    
    void OnCameraStarted(Player player, const string& in roomName, int totalCams)
    {
        if(player == NULL) return;
        
        UpdateCameraInfo(player, roomName, 0, totalCams);
        
        string startMsg = "Camera online";
        if(totalCams > 1)
        {
            startMsg += " (" + formatInt(totalCams) + " available)";
        }
        ShowTemporaryMessage(player, startMsg, 3.0);
    }
    
    void OnCameraStopped(Player player)
    {
        if(player == NULL) return;
        
        int idx = player.GetIndex();
        if(!ValidIndex(idx)) return;
        
        cachedCameraInfo[idx] = "CAMERA: Offline";
        
        ShowTemporaryMessage(player, "Camera deactivated", 2.0);
    }
    
    void SetupPlayerHUD(Player player)
    {
        if(player == NULL || !SCP079Base::IsSCP079Player(player)) return;
        
        CreateHUD(player);
        ShowTemporaryMessage(player, "Surveillance systems online", 4.0);
    }
    
    void CleanupPlayerHUD(Player player)
    {
        if(player == NULL) return;
        
        DestroyHUD(player);
    }
    
    void OnPlayerUpdate(Player player)
    {
        if(player == NULL || !SCP079Base::IsSCP079Player(player)) return;
        
        UpdateHUDPeriodic(player);
    }
    
    void OnPlayerDisconnect(Player player)
    {
        if(player == NULL) return;
        
        CleanupPlayerHUD(player);
    }
}
