/**
 * =====================================================
 * [SS] Bot Manager
 * CubeNet Game Servers
 *
 * CubeNet AI Squad Core
 *
 * Version:
 * 4.0.0
 *
 * Features:
 *  - AI bot profiles
 *  - SQLite database
 *  - Personality system
 *  - Statistics foundation
 *  - Persistent identities
 *
 * =====================================================
 */

#include <sourcemod>
#include <sdktools>


#define ROSTER_FILE "configs/ss_bot_roster.cfg"
#define DATABASE_NAME "ss_botmanager"


Database g_DB;


char g_BotNames[MAXPLAYERS + 1][64];

int g_BotProfile[MAXPLAYERS + 1];

int g_ProfileCount = 0;


enum struct BotProfile
{
	char name[64];
	char classname[32];

	int skill;

	char style[32];

	int aggression;
	int defense;
	int teamwork;
	int risk;
	int objective;

	int kills;
	int deaths;
	int assists;
	int wins;
	int losses;
}



BotProfile g_ProfileData[128];



public Plugin myinfo =
{
	name = "[SS] Bot Manager",
	author = "CubeNet",
	description = "CubeNet AI Squad Core",
	version = "4.0.0",
	url = ""
};



public void OnPluginStart()
{

	ResetDatabase();

	LoadRoster();

        HookEvent(
            "player_spawn",
            Event_PlayerSpawn
        );

        HookEvent(
            "player_death",
            Event_PlayerDeath
        );

        HookEvent(
            "player_healed",
            Event_PlayerAssist
        );


	RegConsoleCmd(
		"sm_botlist",
		Command_BotList
	);


        CreateTimer(
            300.0,
            Timer_SaveStats,
            _,
            TIMER_REPEAT
        );


	PrintToServer(
		"[SS] CubeNet AI Squad Core 4.0.0 Loaded"
	);
}





void ResetDatabase()
{
	char error[255];


	g_DB = SQLite_UseDatabase(
		DATABASE_NAME,
		error,
		sizeof(error)
	);


	if(g_DB == null)
	{
		SetFailState(
			"[SS] SQLite failure: %s",
			error
		);

		return;
	}


	char query[512];


	Format(
		query,
		sizeof(query),
		"DROP TABLE IF EXISTS bots;"
	);


	g_DB.Query(
		SQL_Generic,
		query
	);



	Format(
		query,
		sizeof(query),
		"CREATE TABLE bots (id INTEGER PRIMARY KEY, name TEXT, class TEXT, skill INTEGER, style TEXT, aggression INTEGER, defense INTEGER, teamwork INTEGER, risk INTEGER, objective INTEGER, kills INTEGER DEFAULT 0, deaths INTEGER DEFAULT 0, assists INTEGER DEFAULT 0, wins INTEGER DEFAULT 0, losses INTEGER DEFAULT 0);"
	);


	g_DB.Query(
		SQL_Generic,
		query
	);


	PrintToServer(
		"[SS] Fresh AI database created"
	);
}





public void SQL_Generic(
	Database db,
	DBResultSet results,
	const char[] error,
	any data
)
{
	if(error[0])
	{
		PrintToServer(
			"[SS] SQL Error: %s",
			error
		);
	}
}

// =====================================================
// ROSTER LOADER
// =====================================================


void LoadRoster()
{
	KeyValues kv = new KeyValues("BotRoster");


	char path[PLATFORM_MAX_PATH];


	BuildPath(
		Path_SM,
		path,
		sizeof(path),
		ROSTER_FILE
	);



	if(!kv.ImportFromFile(path))
	{
		PrintToServer(
			"[SS] ERROR: Could not load roster file"
		);

		delete kv;

		return;
	}



	if(!kv.GotoFirstSubKey())
	{
		PrintToServer(
			"[SS] ERROR: No bot profiles found"
		);

		delete kv;

		return;
	}



	int count = 0;



	do
	{



		BotProfile profile;



		kv.GetString(
			"name",
			profile.name,
			sizeof(profile.name)
		);



		kv.GetString(
			"class",
			profile.classname,
			sizeof(profile.classname)
		);



		kv.GetString(
			"style",
			profile.style,
			sizeof(profile.style)
		);



		profile.skill =
			kv.GetNum(
				"skill",
				2
			);



		profile.aggression =
			kv.GetNum(
				"aggression",
				50
			);



		profile.defense =
			kv.GetNum(
				"defense",
				50
			);



		profile.teamwork =
			kv.GetNum(
				"teamwork",
				50
			);



		profile.risk =
			kv.GetNum(
				"risk",
				50
			);



		profile.objective =
			kv.GetNum(
				"objective",
				50
			);



		profile.kills = 0;
		profile.deaths = 0;
		profile.assists = 0;
		profile.wins = 0;
		profile.losses = 0;



		g_ProfileData[count] = profile;



		SaveProfileToDatabase(
			profile
		);



		count++;

                g_ProfileCount = count;


	}
	while(kv.GotoNextKey());



	delete kv;



	PrintToServer(
		"[SS] Loaded %d bot profiles",
		count
	);
}






void SaveProfileToDatabase(
	BotProfile profile
)
{

	char query[1024];


	Format(
		query,
		sizeof(query),

		"INSERT INTO bots (name,class,skill,style,aggression,defense,teamwork,risk,objective) VALUES ('%s','%s',%d,'%s',%d,%d,%d,%d,%d);",

		profile.name,
		profile.classname,
		profile.skill,
		profile.style,
		profile.aggression,
		profile.defense,
		profile.teamwork,
		profile.risk,
		profile.objective
	);



	g_DB.Query(
		SQL_Generic,
		query
	);
}






// =====================================================
// BOT CONNECTION
// =====================================================


public void OnClientPutInServer(
	int client
)
{

	if(!IsFakeClient(client))
		return;



	g_BotNames[client][0] = '\0';


	CreateTimer(
		5.0,
		Timer_AssignBot,
		GetClientUserId(client)
	);

}






public Action Timer_AssignBot(
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



	if(!IsFakeClient(client))
		return Plugin_Stop;



	AssignProfile(
		client
	);



	return Plugin_Stop;
}






void AssignProfile(
	int client
)
{

	static int nextProfile = 0;



	if(nextProfile >= 128)
		return;



        BotProfile profile;

        profile = g_ProfileData[nextProfile];



	strcopy(
		g_BotNames[client],
		sizeof(g_BotNames[]),
		profile.name
	);



	g_BotProfile[client] =
		nextProfile;



	SetClientName(
		client,
		profile.name
	);



	PrintToServer(
		"[SS] Assigned profile:"
	);



	PrintToServer(
		" Name: %s",
		profile.name
	);



	PrintToServer(
		" Class: %s",
		profile.classname
	);



	PrintToServer(
		" Skill: %d",
		profile.skill
	);



	PrintToServer(
		" Style: %s",
		profile.style
	);



	nextProfile++;

}

// =====================================================
// NAME PROTECTION
// =====================================================


public Action Timer_CheckNames(
	Handle timer
)
{

	for(int client = 1; client <= MaxClients; client++)
	{

		if(!IsClientInGame(client))
			continue;


		if(!IsFakeClient(client))
			continue;



		if(g_BotNames[client][0] == '\0')
			continue;



		char current[64];


		GetClientName(
			client,
			current,
			sizeof(current)
		);



		if(!StrEqual(
			current,
			g_BotNames[client]
		))
		{

			SetClientName(
				client,
				g_BotNames[client]
			);



			PrintToServer(
				"[SS] Restored bot identity: %s",
				g_BotNames[client]
			);

		}

	}


	return Plugin_Continue;
}






// =====================================================
// SPAWN PROTECTION
// =====================================================


public void Event_PlayerSpawn(
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
		return;



	if(!IsFakeClient(client))
		return;



	if(g_BotNames[client][0])
	{

		SetClientName(
			client,
			g_BotNames[client]
		);

	}

}






// =====================================================
// BOT STAT TRACKING
// =====================================================


public void Event_PlayerDeath(
	Event event,
	const char[] name,
	bool dontBroadcast
)
{

	int victim =
		GetClientOfUserId(
			event.GetInt("userid")
		);



	int attacker =
		GetClientOfUserId(
			event.GetInt("attacker")
		);



	if(victim > 0)
	{

		if(IsFakeClient(victim))
		{

			int profile =
				g_BotProfile[victim];


			if(profile >= 0)
			{

				g_ProfileData[profile].deaths++;

			}

		}

	}



	if(attacker > 0)
	{

		if(IsFakeClient(attacker))
		{

			int profile =
				g_BotProfile[attacker];


			if(profile >= 0)
			{

				g_ProfileData[profile].kills++;

			}

		}

	}

}







public void Event_PlayerAssist(
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
		return;



	if(!IsFakeClient(client))
		return;



	int profile =
		g_BotProfile[client];



	if(profile >= 0)
	{

		g_ProfileData[profile].assists++;

	}

}






// =====================================================
// SAVE PROFILE DATA
// =====================================================


void SaveAllStats()
{

	for(
		int i = 0;
		i < g_ProfileCount;
		i++
	)
	{

		char query[512];


		Format(
			query,
			sizeof(query),

			"UPDATE bots SET kills=%d,deaths=%d,assists=%d WHERE name='%s';",

			g_ProfileData[i].kills,
			g_ProfileData[i].deaths,
			g_ProfileData[i].assists,
			g_ProfileData[i].name
		);



		g_DB.Query(
			SQL_Generic,
			query
		);

	}


	PrintToServer(
		"[SS] Bot statistics saved"
	);

}







public void OnMapEnd()
{

	SaveAllStats();

}



public Action Timer_SaveStats(
    Handle timer
)
{
    SaveAllStats();

    return Plugin_Continue;
}



// =====================================================
// ADMIN COMMANDS
// =====================================================


public void OnPluginStart_CommandSetup()
{

	RegAdminCmd(
		"sm_botlist",
		Command_BotList,
		ADMFLAG_GENERIC
	);

}






public Action Command_BotList(
	int client,
	int args
)
{

	ReplyToCommand(
		client,
		"[SS] Active Bot Profiles:"
	);



	for(
		int i = 1;
		i <= MaxClients;
		i++
	)
	{

		if(!IsClientInGame(i))
			continue;



		if(!IsFakeClient(i))
			continue;



		ReplyToCommand(
			client,
			"%N -> %s",
			i,
			g_BotNames[i]
		);

	}



	return Plugin_Handled;

}






// =====================================================
// DISCONNECT CLEANUP
// =====================================================


public void OnClientDisconnect(
	int client
)
{

	g_BotNames[client][0] = '\0';


	g_BotProfile[client] = -1;

}
