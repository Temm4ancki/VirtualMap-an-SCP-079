#include "../include/uerm.as"
#include "scp079_hud.as"

namespace SCP079Base
{
    array<bool> activeStates(MAX_PLAYERS + 1, false);
    
    void Initialize()
    {
        for(int i = 0; i <= MAX_PLAYERS; i++)
        {
            activeStates[i] = false;
        }
        SCP079HUD::Initialize();
    }
    
    bool IsSCP079Player(Player player)
    {
        if(player == NULL) return false;
        
        info_Player@ pInfo = GetPlayerInfo(player);
        if(@pInfo != null && @pInfo.pClass != null)
        {
            return pInfo.pClass.roleid == ROLE_SCP_079;
        }
        
        return false;
    }
    
    bool IsPlayerActive(Player player)
    {
        if(player == NULL) return false;
        
        int idx = player.GetIndex();
        if(idx < 0 || idx >= activeStates.size()) return false;
        
        return activeStates[idx];
    }
    
    void SetPlayerActive(Player player, bool state)
    {
        if(player == NULL) return;
        
        int idx = player.GetIndex();
        if(idx < 0 || idx >= activeStates.size()) return;
        
        activeStates[idx] = state;
        
        if(state)
        {
            SCP079HUD::SetupPlayerHUD(player);
        }
        else
        {
            SCP079HUD::CleanupPlayerHUD(player);
        }
    }
    
    void ShowMessage(Player player, const string& in msg, float duration = 3.0)
    {
        if(player == NULL || !IsPlayerActive(player)) return;
        
        SCP079HUD::ShowTemporaryMessage(player, msg, duration);
    }
    
    void SetupPlayer(Player player)
    {
        if(player == NULL || !IsSCP079Player(player)) return;
        
        player.SetInvisible(true);
        player.Desync(true);
        player.Console("noclip");
        player.SetGodmode(true);
        
        SetPlayerActive(player, true);
        
        ShowMessage(player, "Welcome, SCP-079. Surveillance systems online.", 5.0);
    }
    
    void CleanupPlayer(Player player)
    {
        if(player == NULL) return;
        
        SetPlayerActive(player, false);
        
        player.SetInvisible(false);
        player.Desync(false);
        player.Console("noclip");
        player.SetGodmode(false);
    }
    
    void OnPlayerUpdate(Player player)
    {
        if(player == NULL || !IsSCP079Player(player)) return;
        
        if(IsPlayerActive(player))
        {
            player.SetInvisible(true);
            player.Desync(true);
            
            SCP079HUD::OnPlayerUpdate(player);
        }
    }
    
    void OnPlayerDisconnect(Player player)
    {
        if(player == NULL) return;
        
        CleanupPlayer(player);
        SCP079HUD::OnPlayerDisconnect(player);
    }
}
