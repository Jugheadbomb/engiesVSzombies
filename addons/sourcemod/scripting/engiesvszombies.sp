#include <sourcemod>
#include <sdkhooks>
#include <clientprefs>
#include <tf2_stocks>
#include <tf2attributes>
#include <tf2items>
#include <tf_econ_data>
#include <morecolors>
#include <dhooks>

#pragma semicolon 1
#pragma newdecls required

#include "include/evz.inc"

#define PLUGIN_VERSION "1.0.0"

#define TF_MAXPLAYERS 34

#define TF_VISION_FILTER_PYRO (1 << 0)
#define TF_VISION_FILTER_HALLOWEEN (1 << 1)

#define CHANNEL_INFO 1
#define CHANNEL_BONUSROUND 2

TFTeam TFTeam_Zombie = TFTeam_Blue;
TFTeam TFTeam_Survivor = TFTeam_Red;

TFClassType TFClass_Zombie = TFClass_Medic;
TFClassType TFClass_Survivor = TFClass_Engineer;

ConVar mp_autoteambalance;
ConVar mp_scrambleteams_auto;
ConVar mp_disable_respawn_times;
ConVar tf_player_movement_restart_freeze;
ConVar tf_weapon_criticals;
ConVar spec_freeze_time;
ConVar mp_teams_unbalance_limit;
ConVar mp_waitingforplayers_time;
ConVar tf_boost_drain_time;

Cookie g_cForceZombieStart;
bool g_bForceZombieStart[TF_MAXPLAYERS];

bool g_bLastSurvivor;
int g_iKillComboCount[TF_MAXPLAYERS];
float g_flTimeStartAsZombie[TF_MAXPLAYERS];
bool g_bStartedAsZombie[TF_MAXPLAYERS];
bool g_bWaitingForTeamSwitch[TF_MAXPLAYERS];

enum
{
	WeaponSlot_Primary,
	WeaponSlot_Secondary,
	WeaponSlot_Melee,
	WeaponSlot_PDABuild,
	WeaponSlot_PDADestroy,
	WeaponSlot_BuilderEngie
};

enum EVZRoundState
{
	EVZRoundState_Waiting,
	EVZRoundState_Setup,
	EVZRoundState_Active,
	EVZRoundState_Boost,
	EVZRoundState_End
};

EVZRoundState g_nRoundState;
BonusRound g_nBonusRound;

#include "evz/config.sp"
#include "evz/bonusround.sp"
#include "evz/console.sp"
#include "evz/convar.sp"
#include "evz/event.sp"
#include "evz/include.sp"
#include "evz/menu.sp"
#include "evz/sdk.sp"
#include "evz/stocks.sp"

public Plugin myinfo =
{
	name = "[TF2] Engineers VS Zombies",
	author = "Jughead",	
	description = "Zombie Survival Gamemode for TF2",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/profiles/76561198241665788"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	Include_AskLoad();

	RegPluginLibrary("engiesvszombies");
	return APLRes_Success;
}

public void OnPluginStart()
{
	mp_autoteambalance = FindConVar("mp_autoteambalance");
	mp_scrambleteams_auto = FindConVar("mp_scrambleteams_auto");
	mp_disable_respawn_times = FindConVar("mp_disable_respawn_times");
	tf_player_movement_restart_freeze = FindConVar("tf_player_movement_restart_freeze");
	tf_weapon_criticals = FindConVar("tf_weapon_criticals");
	spec_freeze_time = FindConVar("spec_freeze_time");
	mp_teams_unbalance_limit = FindConVar("mp_teams_unbalance_limit");
	mp_waitingforplayers_time = FindConVar("mp_waitingforplayers_time");
	tf_boost_drain_time = FindConVar("tf_boost_drain_time");

	g_cForceZombieStart = new Cookie("evz_forcezombiestart", "TrollFace", CookieAccess_Protected);

	HookEntityOutput("func_respawnroom", "OnStartTouch", RespawnRoom_OnStartTouch);
	HookEntityOutput("func_respawnroom", "OnEndTouch", RespawnRoom_OnEndTouch);

	Config_Init();
	Console_Init();
	ConVar_Init();
	Event_Init();
	SDK_Init();

	g_ConvarInfo.Create("evz_round_time", "300", "Round time in seconds", _, true, 1.0);
	g_ConvarInfo.Create("evz_setup_time", "30", "Setup time in seconds", _, true, 1.0);
	g_ConvarInfo.Create("evz_zombie_boost_time", "60", "Time when zombies are being boosted", _, true, 0.0);
	g_ConvarInfo.Create("evz_ratio", "0.78", "Percentage of players that start as survivors", _, true, 0.01, true, 1.0);
	g_ConvarInfo.Create("evz_melee_ignores_teammates", "1", "If enabled, melee hits will ignore teammates", _, true, 0.0, true, 1.0);
	g_ConvarInfo.Create("evz_bonus_rounds_enable", "1", "Enable/Disable bonus rounds", _, true, 0.0, true, 1.0);
	g_ConvarInfo.Create("evz_bonus_rounds_chance", "0.1", "Chance to start random bonus round", _, true, 0.0, true, 1.0);
	g_ConvarInfo.Create("evz_zombie_teleporters", "1", "If enabled, zombies will be allowed to use teleporters", _, true, 0.0, true, 1.0);
	g_ConvarInfo.Create("evz_zombie_respawn_time", "6.0", "Zombies respawn time in seconds", _, true, 0.0, true, 12.0);
	g_ConvarInfo.Create("evz_zombie_speed_boost", "365.0", "Zombies speed when boosted", _, true, 1.0, true, 520.0);
	g_ConvarInfo.Create("evz_zombie_boost_color", "144 238 144 255", "Zombies render color when boosted");
	g_ConvarInfo.Create("evz_zombie_doublejump_height", "280.0", "Zombies double jump height", _, true, 0.0);
	g_ConvarInfo.Create("evz_zombie_doublejump_height_boost", "380.0", "Zombies double jump height when boosted", _, true, 0.0);

	RegConsoleCmd("sm_evz", Command_MainMenu, "Display main menu of gamemode");
	RegAdminCmd("sm_evz_startbonus", Command_StartBonus, ADMFLAG_CONVARS, "Start random bonus round");

	AutoExecConfig(true, "engiesvszombies");
	LoadTranslations("engiesvszombies.phrases");

	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsClientInGame(iClient))
			OnClientPutInServer(iClient);
}

public void OnMapStart()
{
	PrecacheScriptSound("Announcer.AM_LastManAlive04");
	BonusRound_Precache();
}

public void OnConfigsExecuted()
{
	g_bLastSurvivor = false;

	Config_Refresh();

	if (GameRules_GetRoundState() >= RoundState_Preround)
	{
		TF2_EndRound(TFTeam_Unassigned);
		g_nRoundState = EVZRoundState_End;
	}
	else
		g_nRoundState = EVZRoundState_Waiting;

	BonusRound_Reset();

	CreateTimer(70.0, Timer_WelcomeMessage, _, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(240.0, Timer_WelcomeMessage, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(1.0, Timer_Main, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	Plugin_Cvars(true);
}

public void OnMapEnd()
{
	g_nRoundState = EVZRoundState_End;
}

public void OnPluginEnd()
{
	if (GameRules_GetRoundState() >= RoundState_Preround)
		TF2_EndRound(TFTeam_Unassigned);

	BonusRound_Reset();
	Plugin_Cvars(false);
}

public void OnClientPutInServer(int iClient)
{
	SDKHook(iClient, SDKHook_OnTakeDamageAlive, Client_OnTakeDamageAlive);
	SDKHook(iClient, SDKHook_WeaponSwitchPost, Client_WeaponSwitchPost);
	SDK_OnClientConnect(iClient);
}

public void OnClientCookiesCached(int iClient)
{
	char sValue[8];
	g_cForceZombieStart.Get(iClient, sValue, sizeof(sValue));
	g_bForceZombieStart[iClient] = !!StringToInt(sValue);
}

public void OnClientDisconnect(int iClient)
{
	CheckLastSurvivor(iClient);
	RequestFrame(CheckZombieBypass, iClient);

	g_bWaitingForTeamSwitch[iClient] = false;
}

public void OnEntityCreated(int iEntity, const char[] sClassname)
{
	if (StrEqual(sClassname, "tf_logic_koth") || StrEqual(sClassname, "tf_logic_arena"))
		RemoveEntity(iEntity);
	else if (StrEqual(sClassname, "tf_dropped_weapon") || StrEqual(sClassname, "item_powerup_rune") || StrEqual(sClassname, "item_teamflag"))
		RemoveEntity(iEntity);
	else if (StrEqual(sClassname, "team_control_point"))
		SDKHook(iEntity, SDKHook_Spawn, Point_Spawn);

	SDK_OnEntityCreated(iEntity, sClassname);
}

public void OnGameFrame()
{
	if (!IsActiveRound())
		return;

	int iAlivePlayers = GetPlayerCount(.bAlive = true);
	int iSurvivors = GetPlayerCount(TFTeam_Survivor, true);
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;

		if (IsSurvivor(iClient) && iSurvivors == 1 && iAlivePlayers >= 4)
			TF2_AddCondition(iClient, TFCond_Buffed, 0.05);
	}
}

public void TF2_OnWaitingForPlayersStart()
{
	g_nRoundState = EVZRoundState_Waiting;
}

public void TF2_OnWaitingForPlayersEnd()
{
	g_nRoundState = EVZRoundState_Setup;
}

public void TF2_OnConditionAdded(int iClient, TFCond nCond)
{
	// Prevent receiving crit from halloween candy
	if (TF2_IsHolidayActive(TFHoliday_Halloween) && nCond == TFCond_HalloweenCritCandy)
		TF2_RemoveCondition(iClient, TFCond_HalloweenCritCandy);
}

public Action TF2_OnIsHolidayActive(TFHoliday nHoliday, bool &bResult)
{
	if (nHoliday == TFHoliday_FullMoon || nHoliday == TFHoliday_HalloweenOrFullMoon || nHoliday == TFHoliday_HalloweenOrFullMoonOrValentines)
	{
		bResult = true;
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

public Action TF2_OnPlayerTeleport(int iClient, int iTeleporter, bool &bResult)
{
	if (IsZombie(iClient) && g_ConvarInfo.LookupBool("evz_zombie_teleporters"))
	{
		bResult = true;
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

public Action TF2_CalcIsAttackCritical(int iClient, int iWeapon, char[] sClassname, bool &bResult)
{
	WeaponConfig config;
	if (!WeaponConfig_GetByEntity(iWeapon, config, Value_Index))
		return Plugin_Continue;

	// Gunslinger punch combo hacks
	if (StrEqual(sClassname, "tf_weapon_robot_arm") && config.iKillComboCrit)
	{
		static int iOffsetComboCount = -1;
		if (iOffsetComboCount == -1)
			iOffsetComboCount = FindSendPropInfo("CTFRobotArm", "m_hRobotArm") + 4;	// m_iComboCount

		if (g_iKillComboCount[iClient] == config.iKillComboCrit)
			SetEntData(iWeapon, iOffsetComboCount, 2);
		else
			SetEntData(iWeapon, iOffsetComboCount, 0);
	}

	// Set crit in OnTakeDamageAlive hook, so disable here
	if (config.iKillComboCrit)
	{
		bResult = false;
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

public Action TF2Items_OnGiveNamedItem(int iClient, char[] sClassname, int iIndex, Handle &hItem)
{
	return OnGiveNamedItem(iClient, iIndex);
}

public Action OnPlayerRunCmd(int iClient, int &iButtons, int &iImpulse, float vecVelocity[3], float vecAngles[3], int &iWeapon, int &iSubtype, int &iCmdnum, int &iTickcount, int &iSeed, int iMouse[2])
{
	static int iJumps[TF_MAXPLAYERS];
	static float flLastDamageTime[TF_MAXPLAYERS];

	// Double jump
	if (IsZombie(iClient) || (g_nBonusRound == BonusRound_DoubleDilemma && IsSurvivor(iClient)))
	{
		int iFlags = GetEntityFlags(iClient);
		int iOldButtons = GetEntProp(iClient, Prop_Data, "m_nOldButtons");

		if (!(iOldButtons & IN_JUMP) && (iButtons & IN_JUMP) && !(iFlags & FL_ONGROUND) && iJumps[iClient] < 1)
		{
			iJumps[iClient]++;

			float vecVel[3];
			GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", vecVel);

			if (g_nRoundState == EVZRoundState_Boost && IsZombie(iClient))
				vecVel[2] = g_ConvarInfo.LookupFloat("evz_zombie_doublejump_height_boost");
			else
				vecVel[2] = g_ConvarInfo.LookupFloat("evz_zombie_doublejump_height");

			TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, vecVel);
		}
		else if (iFlags & FL_ONGROUND)
			iJumps[iClient] = 0;
	}

	int iActivewep = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iActivewep > MaxClients)
	{
		WeaponConfig config;
		if (WeaponConfig_GetByEntity(iActivewep, config, Value_Index) && config.bBlockSecondary)
			SetEntPropFloat(iActivewep, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 1.0);
	}

	if (g_nBonusRound == BonusRound_HotPotato)
	{
		float vecVel[3];
		GetEntPropVector(iClient, Prop_Data, "m_vecAbsVelocity", vecVel);
		if (GetVectorLength(vecVel) == 0.0 && flLastDamageTime[iClient] < GetGameTime())
		{
			SDKHooks_TakeDamage(iClient, iClient, iClient, 3.0);
			flLastDamageTime[iClient] = GetGameTime() + 0.25;
		}
	}

	return Plugin_Continue;
}

public void RespawnRoom_OnStartTouch(const char[] sOutput, int iCaller, int iActivator, float flDelay)
{
	if (iActivator <= 0 || iActivator > MaxClients || !IsClientInGame(iActivator))
		return;

	if (view_as<TFTeam>(GetEntProp(iCaller, Prop_Send, "m_iTeamNum")) == TFTeam_Zombie)
	{
		if (IsZombie(iActivator))
			TF2_AddCondition(iActivator, TFCond_UberchargedHidden);
		else if (IsSurvivor(iActivator))
			PrintCenterText(iActivator, "%t", "Hud_ZombieSpawnArea");
	}
}

public void RespawnRoom_OnEndTouch(const char[] sOutput, int iCaller, int iActivator, float flDelay)
{
	if (iActivator <= 0 || iActivator > MaxClients || !IsClientInGame(iActivator))
		return;

	if (view_as<TFTeam>(GetEntProp(iCaller, Prop_Send, "m_iTeamNum")) == TFTeam_Zombie)
	{
		if (IsZombie(iActivator))
			TF2_RemoveCondition(iActivator, TFCond_UberchargedHidden);
	}
}

public void RoundTimer_OnSetupFinished(const char[] sOutput, int iCaller, int iActivator, float flDelay)
{
	if (g_nRoundState != EVZRoundState_Setup)
		return;

	g_nRoundState = EVZRoundState_Active;

	int iEntity = MaxClients + 1;
	while ((iEntity = FindEntityByClassname(iEntity, "func_respawnroom")) > MaxClients)
	{
		if (view_as<TFTeam>(GetEntProp(iEntity, Prop_Send, "m_iTeamNum")) == TFTeam_Survivor)
			AcceptEntityInput(iEntity, "SetInactive");
	}

	int iSurvivors = GetPlayerCount(TFTeam_Survivor, true);
	int iZombies = GetPlayerCount(TFTeam_Zombie);

	// If less than 15% of players are infected, set round start as imbalanced
	bool bImbalanced = (float(iZombies) / float(iSurvivors + iZombies) <= 0.15);

	SetHudTextParams(-1.0, 0.2, 5.0, 255, 255, 255, 255, 1, _, 0.5, 0.5);
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsClientInGame(iClient))
			continue;

		if (g_bWaitingForTeamSwitch[iClient])
			RequestFrame(Frame_PostSetupSpawn, iClient);

		if (IsZombie(iClient) && IsPlayerAlive(iClient))
		{
			SetEntityMoveType(iClient, MOVETYPE_WALK);
			if (bImbalanced)
				SetEntityHealth(iClient, 350);
		}
		else if (IsSurvivor(iClient))
			ShowHudText(iClient, CHANNEL_INFO, "%t", "Hud_ZombiesReleased");

		if (bImbalanced)
			CPrintToChat(iClient, "%t", "Chat_ImbalancedRound", (IsZombie(iClient)) ? "{green}" : "{red}");
	}

	// Check for valid sentries
	int iSentry = MaxClients + 1;
	while ((iSentry = FindEntityByClassname(iSentry, "obj_sentrygun")) > MaxClients)
	{
		int iBuilder = GetEntPropEnt(iSentry, Prop_Send, "m_hBuilder");
		if (0 < iBuilder <= MaxClients && IsClientInGame(iBuilder) && IsAllowedToBuildSentry(iBuilder))
			continue;

		SetVariantInt(GetEntProp(iSentry, Prop_Send, "m_iHealth"));
		AcceptEntityInput(iSentry, "RemoveHealth");
	}

	Forward_OnZombiesRelease();
	SetGlow();
}

public void RoundTimer_OnFinished(const char[] sOutput, int iCaller, int iActivator, float flDelay)
{
	RemoveEntity(iCaller);
	TF2_EndRound(TFTeam_Survivor);
}

public Action Timer_WelcomeMessage(Handle hTimer)
{	
	CPrintToChatAll("%t", "Chat_WelcomeMessage");
	return Plugin_Continue;
}

public Action Timer_Main(Handle hTimer)
{
	if (!IsActiveRound())
		return Plugin_Continue;

	int iTimer = FindEntityByClassname(MaxClients + 1, "team_round_timer");
	if (iTimer > MaxClients && g_nRoundState == EVZRoundState_Active)
	{
		float flTimeRemaining = GetEntPropFloat(iTimer, Prop_Send, "m_flTimerEndTime") - GetGameTime();
		if (RoundToZero(flTimeRemaining) <= g_ConvarInfo.LookupInt("evz_zombie_boost_time"))
		{
			g_nRoundState = EVZRoundState_Boost;

			for (int iClient = 1; iClient <= MaxClients; iClient++)
			{
				if (!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
					continue;

				if (IsZombie(iClient))
				{
					TF2_SetSpeed(iClient, g_ConvarInfo.LookupFloat("evz_zombie_speed_boost"));

					int iColor[4];
					if (g_ConvarInfo.LookupIntArray("evz_zombie_boost_color", iColor, sizeof(iColor)))
					{
						SetEntityRenderMode(iClient, RENDER_TRANSCOLOR);
						SetEntityRenderColor(iClient, iColor[0], iColor[1], iColor[2], iColor[3]);
					}
				}
			}

			Forward_OnZombiesBoost();
		}
	}

	CheckWinCondition();
	SetTeamRespawnTime(TFTeam_Zombie, g_ConvarInfo.LookupFloat("evz_zombie_respawn_time"));

	SetHudTextParams(-1.0, 0.06, 1.1, 0, 0, 255, 200);
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsClientInGame(iClient) || TF2_GetClientTeam(iClient) <= TFTeam_Spectator)
			continue;

		// Zombie boost hud message
		if (g_nRoundState == EVZRoundState_Boost && !(GetClientButtons(iClient) & IN_SCORE))
			ShowHudText(iClient, CHANNEL_INFO, "%t", "Hud_ZombiesBoosted");
	}

	return Plugin_Continue;
}

public Action Timer_GiveAttribs(Handle hTimer, DataPack pack)
{
	pack.Reset();

	int iClient = pack.ReadCell();
	int iWeapon = pack.ReadCell();

	char sAttribSwitch[256];
	pack.ReadString(sAttribSwitch, sizeof(sAttribSwitch));

	int iActiveWep = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iActiveWep == iWeapon)
	{
		char sAttribs[32][32];
		int iCount = ExplodeString(sAttribSwitch, " ; ", sAttribs, sizeof(sAttribs), sizeof(sAttribs));
		if (iCount > 1)
			for (int j = 0; j < iCount; j += 2)
				TF2Attrib_SetByDefIndex(iWeapon, StringToInt(sAttribs[j]), StringToFloat(sAttribs[j+1]));

		TF2Attrib_ClearCache(iWeapon);
		SDK_SetSpeed(iClient);
	}

	return Plugin_Handled;
}

public Action Timer_Zombify(Handle hTimer, int iClient)
{
	if (!IsActiveRound())
		return Plugin_Handled;

	if (IsClientInGame(iClient) && !IsPlayerAlive(iClient))
		SpawnClient(iClient, TFTeam_Zombie);

	return Plugin_Handled;
}

public Action Timer_RespawnPlayer(Handle hTimer, int iClient)
{
	if (IsClientInGame(iClient) && !IsPlayerAlive(iClient))
		TF2_RespawnPlayer2(iClient);

	return Plugin_Handled;
}

public Action Point_Spawn(int iEntity)
{
	// 1 - Hide in HUD, 2 - Hide model
	SetEntProp(iEntity, Prop_Data, "m_spawnflags", GetEntProp(iEntity, Prop_Data, "m_spawnflags")|1|2);
	return Plugin_Continue;
}

public Action Client_OnTakeDamageAlive(int iVictim, int &iAttacker, int &iInflictor, float &flDamage, int &iDamageType, int &iWeapon, float vecForce[3], float vecForcePos[3], int iDamageCustom)
{
	if (IsZombie(iVictim))
	{
		// Disable physics force from sentry damage
		if (iInflictor > MaxClients)
		{
			char sInflictor[64];
			GetEntityClassname(iInflictor, sInflictor, sizeof(sInflictor));
			if (StrEqual(sInflictor, "obj_sentrygun", false))
			{
				iDamageType |= DMG_PREVENT_PHYSICS_FORCE;
				return Plugin_Changed;
			}
		}

		if (iWeapon > MaxClients && 0 < iAttacker <= MaxClients && IsClientInGame(iAttacker) && IsSurvivor(iAttacker))
		{
			WeaponConfig config;
			if (!WeaponConfig_GetByEntity(iWeapon, config, Value_Index) || !config.iKillComboCrit)
				return Plugin_Continue;

			if (g_iKillComboCount[iAttacker] == config.iKillComboCrit)
			{
				iDamageType |= DMG_CRIT;
				flDamage *= 3.0;

				g_iKillComboCount[iAttacker] = 0;
				return Plugin_Changed;
			}
		}
	}
	else if (IsSurvivor(iVictim))
	{
		if (g_nBonusRound == BonusRound_KevlarVests && iAttacker != iVictim)
		{
			if (!g_bUsedVest[iVictim] && flDamage >= GetEntProp(iVictim, Prop_Send, "m_iHealth"))
			{
				if (TF2_IsPlayerInCondition(iVictim, TFCond_Dazed))
					TF2_RemoveCondition(iVictim, TFCond_Dazed);

				g_bUsedVest[iVictim] = true;
				CPrintToChat(iVictim, "%t", "Chat_KevlarUsed");
				TF2_AddCondition(iVictim, TFCond_SpeedBuffAlly, 1.0);

				flDamage = 0.0;
				return Plugin_Changed;
			}
		}
	}

	return Plugin_Continue;
}

public void Client_WeaponSwitchPost(int iClient, int iWeapon)
{
	static int iPreviousWeapon[TF_MAXPLAYERS];

	WeaponConfig config;
	if (WeaponConfig_GetByEntity(iWeapon, config, Value_Index) && config.sAttribSwitch[0])
	{
		DataPack pack;
		CreateDataTimer(GetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack") - GetGameTime(), Timer_GiveAttribs, pack);
		pack.WriteCell(iClient);
		pack.WriteCell(iWeapon);
		pack.WriteString(config.sAttribSwitch);
	}

	if (iPreviousWeapon[iClient] > MaxClients && IsValidEntity(iPreviousWeapon[iClient]))
	{
		if (HasEntProp(iPreviousWeapon[iClient], Prop_Send, "m_iItemDefinitionIndex"))
		{
			if (WeaponConfig_GetByEntity(iPreviousWeapon[iClient], config, Value_Index) && config.sAttribSwitch[0])
			{
				char sAttribs[32][32];
				int iCount = ExplodeString(config.sAttribSwitch, " ; ", sAttribs, sizeof(sAttribs), sizeof(sAttribs));
				if (iCount > 1)
					for (int j = 0; j < iCount; j += 2)
						TF2Attrib_RemoveByDefIndex(iPreviousWeapon[iClient], StringToInt(sAttribs[j]));

				TF2Attrib_ClearCache(iPreviousWeapon[iClient]);
				SDK_SetSpeed(iClient);
			}
		}
	}

	iPreviousWeapon[iClient] = iWeapon;
}

public void Frame_CreateRoundTimer()
{
	int iTimer = TF2_CreateRoundTimer(g_ConvarInfo.LookupInt("evz_setup_time") + 1, g_ConvarInfo.LookupInt("evz_round_time"));
	HookSingleEntityOutput(iTimer, "OnSetupFinished", RoundTimer_OnSetupFinished);
	HookSingleEntityOutput(iTimer, "OnFinished", RoundTimer_OnFinished);
}

public void Frame_CheckZombieBypass(int iClient)
{
	if (TF2_GetClientTeam(iClient) <= TFTeam_Spectator)
		CheckZombieBypass(iClient);
}

public void Frame_PostSetupSpawn(int iClient)
{
	TF2_ChangeClientTeam(iClient, TFTeam_Zombie);
	TF2_RespawnPlayer2(iClient);
	g_bWaitingForTeamSwitch[iClient] = false;
}

public void Frame_SurvivorDeath(int iClient)
{
	CheckWinCondition();
	CheckLastSurvivor(iClient);

	if (IsSurvivor(iClient))
	{
		ClientCommand(iClient, "r_screenoverlay\"debug/yuv\"");
		CreateTimer(3.0, Timer_Zombify, iClient, TIMER_FLAG_NO_MAPCHANGE);

		TF2_ChangeClientTeam(iClient, TFTeam_Zombie);
		TF2_SetPlayerClass(iClient, TFClass_Zombie);

		g_flTimeStartAsZombie[iClient] = GetGameTime();
	}
}

public Action Command_MainMenu(int iClient, int iArgc)
{
	if (iClient == 0)
		return Plugin_Handled;

	Menu_DisplayMain(iClient);
	return Plugin_Handled;
}

public Action Command_StartBonus(int iClient, int iArgc)
{
	if (iClient == 0)
		return Plugin_Handled;

	if (g_nRoundState == EVZRoundState_Waiting || g_nRoundState == EVZRoundState_End)
	{
		CPrintToChat(iClient, "%t", "Chat_NoActiveRound");
		return Plugin_Handled;
	}

	BonusRound_StartRoll();
	return Plugin_Handled;
}

Action OnGiveNamedItem(int iClient, int iIndex)
{
	TFClassType nClass = TF2_GetPlayerClass(iClient);

	int iSlot = TF2Econ_GetItemLoadoutSlot(iIndex, nClass);
	Action action = Plugin_Continue;

	if (IsSurvivor(iClient))
	{
		if (iIndex == GetClassVoodooDefIndex(nClass))
		{
			// Survivors are not zombies
			action = Plugin_Handled;
		}
	}
	else if (IsZombie(iClient))
	{
		if (iSlot < WeaponSlot_Melee)
		{
			// Melee only
			action = Plugin_Handled;
		}
		else if (iSlot > WeaponSlot_BuilderEngie)
		{
			if (TF2Econ_GetItemEquipRegionMask(GetClassVoodooDefIndex(nClass)) & TF2Econ_GetItemEquipRegionMask(iIndex))
			{
				// Cosmetic is conflicting with soul
				action = Plugin_Handled;
			}
		}
	}

	return action;
}

void CheckLastSurvivor(int iIgnoredClient = 0)
{
	if (g_bLastSurvivor)
		return;

	int iLastSurvivor;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;

		if (iClient != iIgnoredClient && IsSurvivor(iClient))
		{
			if (iLastSurvivor) // More than 1 survivors
				return;

			iLastSurvivor = iClient;
		}
	}

	if (!iLastSurvivor)
		return;

	EmitGameSoundToClient(iLastSurvivor, "Announcer.AM_LastManAlive04");
	TF2_AddCondition(iLastSurvivor, TFCond_TeleportedGlow, 5.0);

	g_bLastSurvivor = true;

	Forward_OnLastSurvivor(iLastSurvivor);
}

void CheckZombieBypass(int iClient)
{
	int iSurvivors = GetPlayerCount(TFTeam_Survivor, true);
	int iZombies = GetPlayerCount(TFTeam_Zombie);

	if ((g_flTimeStartAsZombie[iClient] != 0.0)						// Check if client is currently playing as zombie (if it 0.0, it means he have not played as zombie yet this round)
		&& (g_flTimeStartAsZombie[iClient] > GetGameTime() - 90.0)	// Check if client have been playing zombie less than 90 seconds
		&& (float(iZombies) / float(iSurvivors + iZombies) <= 0.6)	// Check if less than 60% of players is zombie
		&& (g_nRoundState != EVZRoundState_End))								// Check if round did not end or map changing
	{
		g_bForceZombieStart[iClient] = true;
		g_cForceZombieStart.Set(iClient, "1");
	}
}

void CheckWinCondition()
{
	bool bFound = false;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient) && IsPlayerAlive(iClient) && IsSurvivor(iClient))
		{
			bFound = true;
			break;
		}
	}

	int iSurvivors = GetPlayerCount(TFTeam_Survivor, true);
	int iZombies = GetPlayerCount(TFTeam_Zombie);

	// If no survivors are alive and at least 1 zombie is playing
	if (!bFound && iZombies > 0)
		TF2_EndRound(TFTeam_Zombie);

	// If no zombies and at least 2 survivors are playing
	else if (iZombies == 0 && iSurvivors > 1)
		TF2_EndRound(TFTeam_Survivor);
}

void SetGlow()
{
	bool bGlow;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;

		bGlow = false;
		if (IsSurvivor(iClient) && IsActiveRound())
		{
			if (GetClientHealth(iClient) <= 30)
				bGlow = true;
		}
		else if (IsZombie(iClient) && g_nRoundState == EVZRoundState_End)
		{
			if (view_as<TFTeam>(GameRules_GetProp("m_iWinningTeam")) == TFTeam_Survivor)
				bGlow = true;
		}

		SetEntProp(iClient, Prop_Send, "m_bGlowEnabled", bGlow);
	}
}

void Plugin_Cvars(bool toggle)
{
	static bool bAutoTeamBalance;
	static bool bScrambleTeamsAuto;
	static bool bDisableRespawnTimes;
	static bool bMovementRestartFreeze;
	static bool bWeaponCriticals;

	static int iSpecFreezeTime;
	static int iTeamsUnbalanceLimit;
	static int iWaitingTime;

	static float flBoostDrainTime;

	static bool toggled = false;

	if (toggle && !toggled)
	{
		toggled = true;

		bAutoTeamBalance = mp_autoteambalance.BoolValue;
		mp_autoteambalance.BoolValue = false;

		bScrambleTeamsAuto = mp_scrambleteams_auto.BoolValue;
		mp_scrambleteams_auto.BoolValue = false;

		bDisableRespawnTimes = mp_disable_respawn_times.BoolValue;
		mp_disable_respawn_times.BoolValue = false;

		bMovementRestartFreeze = tf_player_movement_restart_freeze.BoolValue;
		tf_player_movement_restart_freeze.BoolValue = false;

		bWeaponCriticals = tf_weapon_criticals.BoolValue;
		tf_weapon_criticals.BoolValue = false;

		iSpecFreezeTime = spec_freeze_time.IntValue;
		spec_freeze_time.IntValue = -1;

		iTeamsUnbalanceLimit = mp_teams_unbalance_limit.IntValue;
		mp_teams_unbalance_limit.IntValue = 0;

		iWaitingTime = mp_waitingforplayers_time.IntValue;
		mp_waitingforplayers_time.IntValue = 60;

		flBoostDrainTime = tf_boost_drain_time.FloatValue;
		tf_boost_drain_time.FloatValue = 50.0;
	}
	else if (!toggle && toggled)
	{
		toggled = false;

		mp_autoteambalance.BoolValue = bAutoTeamBalance;
		mp_scrambleteams_auto.BoolValue = bScrambleTeamsAuto;
		mp_disable_respawn_times.BoolValue = bDisableRespawnTimes;
		tf_player_movement_restart_freeze.BoolValue = bMovementRestartFreeze;
		tf_weapon_criticals.BoolValue = bWeaponCriticals;

		spec_freeze_time.IntValue = iSpecFreezeTime;
		mp_teams_unbalance_limit.IntValue = iTeamsUnbalanceLimit;
		mp_waitingforplayers_time.IntValue = iWaitingTime;

		tf_boost_drain_time.FloatValue = flBoostDrainTime;
	}
}