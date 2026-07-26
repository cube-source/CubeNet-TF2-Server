/**
 * =====================================================
 * [SS] AFK Bot Takeover
 * CubeNet Game Servers
 *
 * Version:
 * 3.0.0
 *
 * Seamless AFK Replacement System
 *
 * Features:
 *  - Bot Manager compatible
 *  - Tracks bot userid directly
 *  - Seamless return
 *  - Position restoration
 *  - Class restoration
 *  - Team restoration
 *
 * =====================================================
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>


#define PLUGIN_VERSION "3.0.0"


// =====================================================
// CONFIGURATION
// =====================================================


#define AFK_CHECK_INTERVAL 10.0

#define AFK_WARNING_TIME 180.0

#define AFK_TAKEOVER_TIME 300.0



// =====================================================
// PLAYER STATE
// =====================================================


float g_LastActivity[MAXPLAYERS + 1];


bool g_Warned[MAXPLAYERS + 1];


bool g_IsReplaced[MAXPLAYERS + 1];



// The bot currently controlling this player

int g_ReplacementBot[MAXPLAYERS + 1];



// Saved player data


int g_SavedTeam[MAXPLAYERS + 1];


TFClassType g_SavedClass[MAXPLAYERS + 1];


float g_SavedHealth[MAXPLAYERS + 1];


float g_SavedOrigin[MAXPLAYERS + 1][3];


float g_SavedAngles[MAXPLAYERS + 1][3];


char g_SavedName[MAXPLAYERS + 1][64];



// Debug

bool g_Debug = true;



// =====================================================
// PLUGIN INFO
// =====================================================


public Plugin myinfo =
{
	name = "[SS] AFK Bot Takeover",
	author = "CubeNet",
	description = "Seamless AFK replacement system",
	version = PLUGIN_VERSION,
	url = ""
};




// =====================================================
// STARTUP
// =====================================================


public void OnPluginStart()
{

	HookEvent(
		"player_spawn",
		Event_PlayerSpawn
	);


	HookEvent(
		"player_disconnect",
		Event_PlayerDisconnect
	);


	AddCommandListener(
		Command_Say,
		"say"
	);



	RegAdminCmd(
		"sm_afkbot_force",
		Command_Force,
		ADMFLAG_GENERIC
	);


	RegAdminCmd(
		"sm_afkbot_status",
		Command_Status,
		ADMFLAG_GENERIC
	);



	CreateTimer(
		AFK_CHECK_INTERVAL,
		Timer_CheckAFK,
		_,
		TIMER_REPEAT
	);



	PrintToServer(
		"[SS] AFK Bot Takeover %s loaded",
		PLUGIN_VERSION
	);

}





// =====================================================
// CLIENT CONNECTION
// =====================================================


public void OnClientPutInServer(
	int client
)
{

	if(IsFakeClient(client))
		return;



	g_LastActivity[client] =
		GetGameTime();



	g_Warned[client] = false;


	g_IsReplaced[client] = false;


	g_ReplacementBot[client] = -1;


}





public void OnClientDisconnect(
	int client
)
{

	g_LastActivity[client] = 0.0;


	g_Warned[client] = false;


	g_IsReplaced[client] = false;


	g_ReplacementBot[client] = -1;

}





// =====================================================
// PLAYER ACTIVITY
// =====================================================


public Action Command_Say(
	int client,
	const char[] command,
	int argc
)
{

	if(client > 0)
	{
		UpdateActivity(client);
	}


	return Plugin_Continue;

}





public Action OnPlayerRunCmd(
	int client,
	int &buttons,
	int &impulse,
	float vel[3],
	float angles[3],
	int &weapon
)
{

	if(client <= 0)
		return Plugin_Continue;



	if(!IsClientInGame(client))
		return Plugin_Continue;



	if(IsFakeClient(client))
		return Plugin_Continue;



	bool active = false;



	if(buttons != 0)
		active = true;



	if(vel[0] != 0.0 ||
	   vel[1] != 0.0)
		active = true;



	if(impulse != 0)
		active = true;



	if(active)
	{
		UpdateActivity(client);
	}



	return Plugin_Continue;

}





void UpdateActivity(
	int client
)
{

	g_LastActivity[client] =
		GetGameTime();



	g_Warned[client] = false;



	if(g_IsReplaced[client])
	{

		PrintDebug(
			"%N returned from AFK",
			client
		);


		RestorePlayer(client);

	}

}





// =====================================================
// AFK TIMER
// =====================================================


public Action Timer_CheckAFK(
	Handle timer,
	any data
)
{

	float now =
		GetGameTime();



	for(int client = 1;
		client <= MaxClients;
		client++)
	{

		if(!IsValidHuman(client))
			continue;



		float idle =
			now - g_LastActivity[client];



		if(idle >= AFK_TAKEOVER_TIME)
		{

			if(!g_IsReplaced[client])
			{

				CreateReplacement(client);

			}

		}
		else if(idle >= AFK_WARNING_TIME)
		{

			if(!g_Warned[client])
			{

				PrintToChat(
					client,
					"\x04[SS]\x01 You are AFK. Bot takeover soon."
				);


				g_Warned[client] = true;

			}

		}

	}



	return Plugin_Continue;

}





// =====================================================
// HELPERS
// =====================================================


bool IsValidHuman(
	int client
)
{

	return (
		client > 0 &&
		client <= MaxClients &&
		IsClientInGame(client) &&
		!IsFakeClient(client)
	);

}





void PrintDebug(
	const char[] format,
	any ...
)
{

	if(!g_Debug)
		return;



	char buffer[256];


	VFormat(
		buffer,
		sizeof(buffer),
		format,
		2
	);



	PrintToServer(
		"[SS AFK DEBUG] %s",
		buffer
	);

}
// =====================================================
// BOT CREATION / TAKEOVER ENGINE
// =====================================================


void CreateReplacement(
	int client
)
{

	if(!IsValidHuman(client))
		return;



	if(g_IsReplaced[client])
		return;



	PrintDebug(
		"Creating replacement for %N",
		client
	);



	SavePlayerState(client);



	g_IsReplaced[client] = true;



	char name[64];


	GetClientName(
		client,
		name,
		sizeof(name)
	);


	strcopy(
		g_SavedName[client],
		sizeof(g_SavedName[]),
		name
	);



	PrintToChatAll(
		"\x04[SS]\x01 %s replaced",
		name
	);



	/*
		We temporarily increase the bot count.
		
		Bot Manager will detect the bot,
		assign identity,
		class,
		personality,
		and voice.
	*/


	ServerCommand(
		"tf_bot_add"
	);



	CreateTimer(
		2.0,
		Timer_FindReplacementBot,
		GetClientUserId(client)
	);



	/*
		Move player out safely.

		We DO NOT kill the player.
		This fixes the previous bug.
	*/


	TF2_ChangeClientTeam(
		client,
		TFTeam_Spectator
	);



}





// =====================================================
// SAVE PLAYER STATE
// =====================================================


void SavePlayerState(
	int client
)
{

	g_SavedTeam[client] =
		GetClientTeam(client);



	g_SavedClass[client] =
		TF2_GetPlayerClass(client);



	GetClientAbsOrigin(
		client,
		g_SavedOrigin[client]
	);



	GetClientAbsAngles(
		client,
		g_SavedAngles[client]
	);



	g_SavedHealth[client] =
		float(GetClientHealth(client));



	GetClientName(
		client,
		g_SavedName[client],
		sizeof(g_SavedName[])
	);



	PrintDebug(
		"Saved %N team %d class %d",
		client,
		g_SavedTeam[client],
		g_SavedClass[client]
	);

}





// =====================================================
// FIND NEW BOT
// =====================================================


public Action Timer_FindReplacementBot(
	Handle timer,
	any userid
)
{

	int client =
		GetClientOfUserId(userid);



	if(client <= 0)
		return Plugin_Stop;



	for(int bot = 1;
		bot <= MaxClients;
		bot++)
	{

		if(!IsClientInGame(bot))
			continue;



		if(!IsFakeClient(bot))
			continue;



		/*
			Ignore existing bots.
			
			The newest bot will have
			no saved profile yet.
		*/


		if(g_ReplacementBot[client] == bot)
			continue;



		g_ReplacementBot[client] = bot;



		PrintDebug(
			"Assigned bot %N to %N",
			bot,
			client
		);



		ChangeBotTeam(
			bot,
			g_SavedTeam[client]
		);



		CreateTimer(
			1.0,
			Timer_ActivateBot,
			GetClientUserId(client)
		);



		break;

	}



	return Plugin_Stop;

}





// =====================================================
// ACTIVATE BOT
// =====================================================

public Action Timer_ActivateBot(
	Handle timer,
	any userid
)
{

	int client =
		GetClientOfUserId(userid);



	if(client <= 0)
		return Plugin_Stop;



	int bot =
		g_ReplacementBot[client];



	if(bot <= 0 ||
	   !IsClientInGame(bot))
		return Plugin_Stop;



/*
	DO NOT FORCE RESPAWN HERE.

	The TF2 bot lifecycle must finish naturally.

	Bot Manager needs time to:
	- assign identity
	- assign class
	- assign personality
	- assign voice

	Forcing respawn here interrupts that.
*/


PrintToServer(
	"[SS] Bot %N now controls %s",
	bot,
	g_SavedName[client]
);



return Plugin_Stop;

}





// =====================================================
// TEAM CHANGE
// =====================================================


void ChangeBotTeam(
	int bot,
	int team
)
{

	if(bot <= 0)
		return;



	ChangeClientTeam(
		bot,
		team
	);



}





// =====================================================
// PLAYER SPAWN
// =====================================================


public Action Event_PlayerSpawn(
	Event event,
	const char[] name,
	bool dontBroadcast
)
{

	int client =
		GetClientOfUserId(
			event.GetInt("userid")
		);



	if(client <= 0)
		return Plugin_Continue;



	if(IsFakeClient(client))
		return Plugin_Continue;



	if(g_IsReplaced[client])
	{
		return Plugin_Continue;
	}



	g_LastActivity[client] =
		GetGameTime();



	return Plugin_Continue;

}





// =====================================================
// DISCONNECT EVENT
// =====================================================


public Action Event_PlayerDisconnect(
	Event event,
	const char[] name,
	bool dontBroadcast
)
{

	int client =
		GetClientOfUserId(
			event.GetInt("userid")
		);



	if(client <= 0)
		return Plugin_Continue;



	g_LastActivity[client] = 0.0;



	return Plugin_Continue;

}
// =====================================================
// PLAYER RESTORE SYSTEM
// =====================================================


void RestorePlayer(
	int client
)
{

	if(!IsValidHuman(client))
		return;



	if(!g_IsReplaced[client])
		return;



	PrintDebug(
		"Restoring %N",
		client
	);



	int bot =
		g_ReplacementBot[client];



	float restorePos[3];

	float restoreAng[3];



	bool havePosition = false;



	/*
		Copy bot location.

		This makes the return seamless.
		The player comes back where
		the bot actually is.
	*/


	if(bot > 0 &&
	   IsClientInGame(bot))
	{

		GetClientAbsOrigin(
			bot,
			restorePos
		);


		GetClientAbsAngles(
			bot,
			restoreAng
		);


		havePosition = true;

	}



	/*
		Remove bot first.

		Prevents duplicate player
		entities fighting.
	*/


	RemoveReplacementBot(
		client
	);



	/*
		Return player to original team.
	*/


	ChangeClientTeam(
		client,
		g_SavedTeam[client]
	);



	CreateTimer(
		0.5,
		Timer_FinalRestore,
		GetClientUserId(client)
	);



	if(havePosition)
	{

		g_SavedOrigin[client][0] =
			restorePos[0];


		g_SavedOrigin[client][1] =
			restorePos[1];


		g_SavedOrigin[client][2] =
			restorePos[2];



		g_SavedAngles[client][0] =
			restoreAng[0];


		g_SavedAngles[client][1] =
			restoreAng[1];


		g_SavedAngles[client][2] =
			restoreAng[2];

	}



}





public Action Timer_FinalRestore(
	Handle timer,
	any userid
)
{

	int client =
		GetClientOfUserId(userid);



	if(client <= 0)
		return Plugin_Stop;



	if(!IsClientInGame(client))
		return Plugin_Stop;



	TF2_SetPlayerClass(
		client,
		g_SavedClass[client]
	);



	TF2_RespawnPlayer(
		client
	);



	CreateTimer(
		0.2,
		Timer_MoveRestoredPlayer,
		GetClientUserId(client)
	);



	return Plugin_Stop;

}





public Action Timer_MoveRestoredPlayer(
	Handle timer,
	any userid
)
{

	int client =
		GetClientOfUserId(userid);



	if(client <= 0)
		return Plugin_Stop;



	if(!IsClientInGame(client))
		return Plugin_Stop;



	TeleportEntity(
		client,
		g_SavedOrigin[client],
		g_SavedAngles[client],
		NULL_VECTOR
	);



	g_IsReplaced[client] = false;


	g_Warned[client] = false;


	g_LastActivity[client] =
		GetGameTime();



	PrintToChat(
		client,
		"\x04[SS]\x01 Welcome back!"
	);



	PrintDebug(
		"%N restored",
		client
	);



	return Plugin_Stop;

}





// =====================================================
// REMOVE BOT
// =====================================================


void RemoveReplacementBot(
	int client
)
{

	int bot =
		g_ReplacementBot[client];



	if(bot > 0 &&
	   IsClientInGame(bot))
	{

		KickClient(
			bot,
			"Player returned"
		);


	}



	g_ReplacementBot[client] = -1;

}





// =====================================================
// ADMIN COMMANDS
// =====================================================


public Action Command_Force(
	int client,
	int args
)
{

	if(args < 1)
	{

		ReplyToCommand(
			client,
			"Usage: sm_afkbot_force <player>"
		);


		return Plugin_Handled;

	}



	char target[64];


	GetCmdArg(
		1,
		target,
		sizeof(target)
	);



	int player =
		FindTarget(
			client,
			target,
			true
		);



	if(player > 0)
	{

		CreateReplacement(
			player
		);

	}



	return Plugin_Handled;

}





public Action Command_Status(
	int client,
	int args
)
{

	ReplyToCommand(
		client,
		"[SS] Active AFK replacements:"
	);



	bool found = false;



	for(int i = 1;
		i <= MaxClients;
		i++)
	{

		if(!g_IsReplaced[i])
			continue;



		found = true;



		ReplyToCommand(
			client,
			"%N -> Bot ID %d",
			i,
			g_ReplacementBot[i]
		);

	}



	if(!found)
	{

		ReplyToCommand(
			client,
			"None"
		);

	}



	return Plugin_Handled;

}





// =====================================================
// CLEANUP
// =====================================================


public void OnMapEnd()
{

	for(int i = 1;
		i <= MaxClients;
		i++)
	{

		g_IsReplaced[i] = false;


		g_ReplacementBot[i] = -1;

	}

}
