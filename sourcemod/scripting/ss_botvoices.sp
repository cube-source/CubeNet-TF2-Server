#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.4"

#define VOICE_COOLDOWN 190.0
#define KILL_COOLDOWN 300.0
#define OBJECTIVE_CHANCE 4


Handle g_VoiceTimer[MAXPLAYERS+1];

float g_LastVoice[MAXPLAYERS+1];
float g_LastKillVoice[MAXPLAYERS+1];


public Plugin myinfo =
{
	name = "[SS] Bot Voices",
	author = "CubeNet",
	description = "Personality announcements for SS bots",
	version = PLUGIN_VERSION
};



public void OnPluginStart()
{
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("teamplay_point_captured", Event_Objective);

	RegConsoleCmd(
		"sm_botvoices_test",
		Command_TestVoice
	);
}



public void OnClientDisconnect(int client)
{
	if(g_VoiceTimer[client] != null)
	{
		delete g_VoiceTimer[client];
		g_VoiceTimer[client] = null;
	}


	g_LastVoice[client] = 0.0;
	g_LastKillVoice[client] = 0.0;
}





public void Event_PlayerSpawn(
	Event event,
	const char[] name,
	bool dontBroadcast
)
{
	int client = GetClientOfUserId(
		event.GetInt("userid")
	);


	if(!IsSSBot(client))
		return;


	if(g_VoiceTimer[client] != null)
		delete g_VoiceTimer[client];


	g_VoiceTimer[client] = CreateTimer(
		5.0,
		Timer_SpawnVoice,
		client
	);
}





public Action Timer_SpawnVoice(
	Handle timer,
	any client
)
{
	g_VoiceTimer[client] = null;


	if(IsClientInGame(client))
	{
		SendVoice(client,"spawn");
	}


	return Plugin_Stop;
}






public void Event_PlayerDeath(
	Event event,
	const char[] name,
	bool dontBroadcast
)
{
	int victim = GetClientOfUserId(
		event.GetInt("userid")
	);

	int attacker = GetClientOfUserId(
		event.GetInt("attacker")
	);



	// Kill voice
	if(IsSSBot(attacker))
	{
		float now = GetGameTime();


		if(now - g_LastKillVoice[attacker] >= KILL_COOLDOWN)
		{
			SendVoice(
				attacker,
				"kill"
			);


			g_LastKillVoice[attacker] = now;
		}
	}



	// Death voice
	if(IsSSBot(victim))
	{
		SendVoice(
			victim,
			"death"
		);
	}
}







public void Event_Objective(
	Event event,
	const char[] name,
	bool dontBroadcast
)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsSSBot(i))
			continue;


		// Only allow some bots to respond
		if(GetRandomInt(0,OBJECTIVE_CHANCE) != 0)
			continue;


		SendVoice(
			i,
			"objective"
		);
	}
}







bool IsSSBot(int client)
{
	if(client <= 0)
		return false;


	if(!IsClientInGame(client))
		return false;


	if(!IsFakeClient(client))
		return false;


	char name[64];

	GetClientName(
		client,
		name,
		sizeof(name)
	);


	return StrContains(
		name,
		"[SS]"
	) != -1;
}








void GetBotKey(
	int client,
	char[] output,
	int size
)
{
	char name[64];


	GetClientName(
		client,
		name,
		sizeof(name)
	);


	strcopy(
		output,
		size,
		name
	);


	ReplaceString(
		output,
		size,
		"[SS]",
		""
	);


	TrimString(output);
}








void NormalizeName(
	char[] name,
	int size
)
{
	ReplaceString(
		name,
		size,
		"[SS]",
		""
	);


	TrimString(name);
}








void SendVoice(
	int client,
	const char[] eventName
)
{
	if(client <= 0 || !IsClientInGame(client))
		return;



	float now = GetGameTime();



	if(now - g_LastVoice[client] < VOICE_COOLDOWN)
		return;





	char botKey[64];


	GetBotKey(
		client,
		botKey,
		sizeof(botKey)
	);





	char path[PLATFORM_MAX_PATH];


	BuildPath(
		Path_SM,
		path,
		sizeof(path),
		"configs/ss_botvoices.cfg"
	);





	KeyValues kv = new KeyValues(
		"BotVoices"
	);



	if(!kv.ImportFromFile(path))
	{
		PrintToServer(
			"[SS] Cannot load %s",
			path
		);


		delete kv;
		return;
	}






	PrintToServer(
		"[SS] Voice lookup: %s -> %s",
		botKey,
		eventName
	);






	if(!kv.JumpToKey(botKey))
	{
		PrintToServer(
			"[SS] No voice profile found for %s",
			botKey
		);


		delete kv;
		return;
	}






	if(!kv.JumpToKey(eventName))
	{
		PrintToServer(
			"[SS] No %s voice found for %s",
			eventName,
			botKey
		);


		delete kv;
		return;
	}






	char lines[10][128];

	int count = 0;






	if(kv.GotoFirstSubKey(false))
	{
		do
		{
			kv.GetString(
				NULL_STRING,
				lines[count],
				sizeof(lines[])
			);


			count++;


		}
		while(
			count < 10 &&
			kv.GotoNextKey(false)
		);
	}







	if(count)
	{
		int pick = GetRandomInt(
			0,
			count-1
		);



		char display[64];


		GetClientName(
			client,
			display,
			sizeof(display)
		);




		PrintToChatAll(
			"\x04%s\x01: %s",
			display,
			lines[pick]
		);



		g_LastVoice[client] = now;
	}






	delete kv;
}









public Action Command_TestVoice(
	int client,
	int args
)
{
	if(args < 1)
	{
		ReplyToCommand(
			client,
			"[SS] Usage: sm_botvoices_test <name>"
		);


		return Plugin_Handled;
	}





	char target[64];


	GetCmdArgString(
		target,
		sizeof(target)
	);




	NormalizeName(
		target,
		sizeof(target)
	);





	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsSSBot(i))
			continue;



		char key[64];


		GetBotKey(
			i,
			key,
			sizeof(key)
		);




		if(StrEqual(
			key,
			target,
			false
		))
		{
			SendVoice(
				i,
				"spawn"
			);


			return Plugin_Handled;
		}
	}





	ReplyToCommand(
		client,
		"[SS] Bot not found: %s",
		target
	);



	return Plugin_Handled;
}
