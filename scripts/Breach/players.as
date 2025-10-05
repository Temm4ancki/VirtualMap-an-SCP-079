#include "scp079/scp079.as"

void SetPlayerRole(Player p, Role@ targetRole, int texture = -1)
{
	if(@playerInfo.pClass != @targetRole) 
	{
		switch(playerInfo.pClass.roleid) 
		{
			case ROLE_SCP_079:
			{
				SetupSCP079ForPlayer(p);
				break;
			}
		}
	}
}

void NullPlayerStats(Player p)
{
	if(@prevRole != null && prevRole.roleid == ROLE_SCP_079)
	{
		SCP079::StopCameraForPlayer(p);
		SCP079::OnPlayerDisconnect(p);
	}
}

namespace PlayerCallbacks
{
	void OnConnect(Player player)
	{
		SCP079Map::OnPlayerConnect(player);
	}

	bool OnChat(Player player, string message)
	{
		
		if(message.substr(0, 1) == "/") 
		{
			if(ProcessSCP079Command(player, message))
			{
				return false;
			}
		}
	}
}