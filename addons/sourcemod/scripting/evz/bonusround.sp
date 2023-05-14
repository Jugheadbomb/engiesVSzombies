#define BONUSROUND_CONFIG "configs/evz/bonusrounds.cfg"
#define BONUSROUND_ROLLSOUND "evz/bonusround.wav"

static ArrayList g_aRounds;

enum struct BonusRound
{
	// Static
	char id[64];
	char sName[64];
	char sDesc[64];
	char sClass[64];
	char start_sound[PLATFORM_MAX_PATH];
	bool bShowInHUD;
	bool bSetupOnly;
	bool bEnabled;
	KeyValues data;

	// Runtime
	bool bActive;
	bool bForced;

	void ReadFromKv(KeyValues kv)
	{
		if (kv.GetSectionName(this.id, sizeof(this.id)))
		{
			this.bShowInHUD = !!kv.GetNum("showinhud", 1);
			this.bSetupOnly = !!kv.GetNum("setuponly");
			this.bEnabled = !!kv.GetNum("enabled", 1);

			kv.GetString("name", this.sName, sizeof(this.sName));
			kv.GetString("desc", this.sDesc, sizeof(this.sDesc));
			kv.GetString("round_class", this.sClass, sizeof(this.sClass));
			kv.GetString("start_sound", this.start_sound, sizeof(this.start_sound));

			if (kv.JumpToKey("data", false))
			{
				this.data = new KeyValues("data");
				this.data.Import(kv);
				kv.GoBack();
			}
		}
	}

	bool StartFunction(const char[] sFunction, Handle hPlugin = null)
	{
		if (!this.sClass[0])
			return false;

		char sBuffer[64];
		Format(sBuffer, sizeof(sBuffer), "%s_%s", this.sClass, sFunction);

		Function func = GetFunctionByName(hPlugin, sBuffer);
		if (func == INVALID_FUNCTION)
			return false;

		Call_StartFunction(hPlugin, func);
		Call_PushArray(this, sizeof(this));
		return true;
	}
}

methodmap RoundList
{
	public static ArrayList GetList()
	{
		return g_aRounds;
	}

	public static void Init()
	{
		char sFilePath[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, sFilePath, sizeof(sFilePath), BONUSROUND_CONFIG);

		KeyValues kv = new KeyValues("bonusrounds");
		if (kv.ImportFromFile(sFilePath))
		{
			if (kv.GotoFirstSubKey(false))
			{
				do
				{
					BonusRound round;
					round.ReadFromKv(kv);

					if (g_aRounds.FindString(round.id) != -1)
					{
						LogError("Round '%T' has duplicate ID '%s', skipping...", round.sName, LANG_SERVER, round.id);
						continue;
					}

					if (round.StartFunction("Create") && Call_Finish() != SP_ERROR_NONE)
						continue;

					g_aRounds.PushArray(round);
				}
				while (kv.GotoNextKey(false));
				kv.GoBack();
			}
			kv.GoBack();
		}
		else
			LogError("Could not read from file '%s'", sFilePath);

		delete kv;
	}

	public static void Precache()
	{
		PrepareSound(BONUSROUND_ROLLSOUND);

		for (int i = 0; i < g_aRounds.Length; i++)
		{
			BonusRound round;
			if (g_aRounds.GetArray(i, round) && round.StartFunction("Precache"))
				Call_Finish();
		}
	}

	public static bool GetActive(BonusRound round)
	{
		for (int i = 0; i < g_aRounds.Length; i++)
		{
			if (g_aRounds.GetArray(i, round) && round.bActive)
				return true;
		}

		return false;
	}

	public static bool StartRound(BonusRound round)
	{
		int index = g_aRounds.FindString(round.id);
		if (index == -1)
		{
			LogError("Failed to activate unknown round with id '%s'", round.id);
			return false;
		}

		if (round.bSetupOnly && IsActiveRound())
			return false;

		RoundList.EndRound();

		bool bReturn;
		if (round.StartFunction("OnStart"))
		{
			if (Call_Finish(bReturn) != SP_ERROR_NONE || !bReturn)
			{
				LogMessage("Skipped round '%T' because 'OnStart' callback returned false", round.sName, LANG_SERVER);
				return false;
			}
		}

		g_aRounds.Set(index, true, BonusRound::bActive);

		EmitGameSoundToAll("CYOA.NodeActivate");

		if (round.start_sound[0])
			PlayStaticSound(round.start_sound);

		return true;
	}

	public static bool EndRound()
	{
		for (int i = 0; i < g_aRounds.Length; i++)
		{
			BonusRound round;
			if (g_aRounds.GetArray(i, round) && round.bActive)
			{
				g_aRounds.Set(i, false, BonusRound::bActive);

				if (round.StartFunction("OnEnd"))
					Call_Finish();

				if (round.start_sound[0])
					StopStaticSound(round.start_sound);
			}
		}
	}
}

void BonusRound_Init()
{
	g_aRounds = new ArrayList(sizeof(BonusRound));
	RoundList.Init();
}

void BonusRound_StartRoll()
{
	RoundList.EndRound();

	int iEntity = CreateEntityByName("game_text_tf");

	DispatchKeyValue(iEntity, "message", "BONUS ROUND!");
	DispatchKeyValue(iEntity, "icon", "voice_self");
	DispatchKeyValue(iEntity, "display_to_team", "0");
	DispatchKeyValue(iEntity, "background", "0");
	DispatchSpawn(iEntity);

	AcceptEntityInput(iEntity, "Display");
	RemoveEntity(iEntity);

	CreateTimer(0.1, BonusRound_RollTimer, GetGameTime() + 2.6, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	EmitSoundToAll(BONUSROUND_ROLLSOUND);
}

Action BonusRound_RollTimer(Handle hTimer, float flEndTime)
{
	static int index = 0;
	static bool bSelected = false;
	BonusRound round;

	int iColor[3];
	for (int i = 0; i < sizeof(iColor); i++)
		iColor[i] = (GetURandomInt() % 206) + 50; // From 50 to 255

	float flTime = GetGameTime();
	if (flTime >= flEndTime)
	{
		if (!bSelected)
		{
			bSelected = true;

			ArrayList aClone = g_aRounds.Clone();
			aClone.Sort(Sort_Random, Sort_Integer);

			for (int i = 0; i < aClone.Length; i++)
			{
				if (aClone.GetArray(i, round) && round.bEnabled)
				{
					if (round.bSetupOnly && IsActiveRound())
						continue;

					SetHudTextParams(-1.0, 0.3, 6.0, iColor[0], iColor[1], iColor[2], 255, 1, _, 0.0, 0.5);
					if (round.sDesc[0])
						ShowHudTextAll(CHANNEL_BONUSROUND, "★ %t ★\n%t\n%t", "#Hud_BonusRound", round.sName, round.sDesc);
					else
						ShowHudTextAll(CHANNEL_BONUSROUND, "★ %t ★\n%t", "#Hud_BonusRound", round.sName);
					break;
				}
			}

			delete aClone;
		}

		if (flTime + 1.0 >= flEndTime)
		{
			bSelected = false;
			RoundList.StartRound(round);
			return Plugin_Stop;
		}
	}
	else if (g_aRounds.GetArray(index, round))
	{
		SetHudTextParams(-1.0, 0.3, 0.1, iColor[0], iColor[1], iColor[2], 200, 1, _, 0.0, 0.0);
		ShowHudTextAll(CHANNEL_BONUSROUND, "%t", round.sName);
	}

	if (++index >= g_aRounds.Length)
		index = 0;

	return Plugin_Continue;
}