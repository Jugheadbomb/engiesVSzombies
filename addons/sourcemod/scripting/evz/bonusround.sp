#define BONUSROUND_ROLLSOUND "evz/bonusround.wav"

bool g_bUsedVest[TF_MAXPLAYERS];

void BonusRound_Precache()
{
	PrepareSound(BONUSROUND_ROLLSOUND);
}

void BonusRound_StartRoll()
{
	BonusRound_Reset();

	int iEntity = CreateEntityByName("game_text_tf");

	DispatchKeyValue(iEntity, "message", "BONUS ROUND!");
	DispatchKeyValue(iEntity, "icon", "voice_self");
	DispatchKeyValue(iEntity, "display_to_team", "0");
	DispatchKeyValue(iEntity, "background", "0");
	DispatchSpawn(iEntity);

	AcceptEntityInput(iEntity, "Display");
	RemoveEntity(iEntity);

	CreateTimer(0.1, BonusRound_Roll, GetGameTime() + 2.6, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsClientInGame(iClient))
			EmitSoundToClient(iClient, BONUSROUND_ROLLSOUND);
}

Action BonusRound_Roll(Handle hTimer, float flEndTime)
{
	static int index = 0;
	RoundConfig round;

	if (GetGameTime() >= flEndTime)
	{
		if (g_RoundList.GetRandom(round))
		{
			BonusRound_DisplayRound(round, true);
			BonusRound_StartRound(round.id);
		}

		return Plugin_Stop;
	}

	if (g_RoundList.GetArray(index, round, sizeof(round)))
		BonusRound_DisplayRound(round, false);

	if (++index >= g_RoundList.Length)
		index = 0;

	return Plugin_Continue;
}

void BonusRound_DisplayRound(RoundConfig round, bool bFull)
{
	int iColor[4];
	iColor[0] = (GetURandomInt() % 206) + 50; // From 50 to 255
	iColor[1] = (GetURandomInt() % 206) + 50;
	iColor[2] = (GetURandomInt() % 206) + 50;
	iColor[3] = bFull ? 255 : 200;

	SetHudTextParams(-1.0, 0.3, bFull ? 6.0 : 0.1, iColor[0], iColor[1], iColor[2], iColor[3], 1, _, 0.0, bFull ? 0.5 : 0.0);
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsClientInGame(iClient))
			continue;

		if (bFull)
		{
			ShowHudText(iClient, CHANNEL_BONUSROUND, "★ %t ★\n%t\n%t", "Hud_BonusRound", round.sName, round.sDesc);
			CPrintToChat(iClient, "{immortal}%t: {darkorange}%t\n{darkviolet}%t", "Hud_BonusRound", round.sName, round.sDesc);
		}
		else
			ShowHudText(iClient, CHANNEL_BONUSROUND, "%t", round.sName);
	}
}

void BonusRound_StartRound(BonusRound id)
{
	BonusRound_Reset();

	switch (id)
	{
		case BonusRound_None: return;
		case BonusRound_NoDispensers: SendEntityInput("obj_dispenser", "Kill");
		case BonusRound_EarlyOutbreak:
		{
			int iTimer = FindEntityByClassname(-1, "team_round_timer");
			if (iTimer > MaxClients)
			{
				SetVariantInt(1);
				AcceptEntityInput(iTimer, "SetSetupTime");
			}
		}
		case BonusRound_DoubleDilemma: SendEntityInput("obj_teleporter", "Kill");
		case BonusRound_RandomFits:
		{
			tf_weapon_criticals.Flags &= ~FCVAR_NOTIFY;
			tf_weapon_criticals.BoolValue = true;
			tf_weapon_criticals.Flags |= FCVAR_NOTIFY;
		}
		case BonusRound_TeamSwap:
		{
			TFTeam nTemp = TFTeam_Zombie;
			TFTeam_Zombie = TFTeam_Survivor;
			TFTeam_Survivor = nTemp;

			for (int iClient = 1; iClient <= MaxClients; iClient++)
			{
				if (!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
					continue;

				SpawnClient(iClient, IsSurvivor(iClient) ? TFTeam_Zombie : TFTeam_Survivor);
			}
		}
	}

	g_nBonusRound = id;

	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient) && IsPlayerAlive(iClient))
			BonusRound_PlayerSpawn(iClient);
	}
}

void BonusRound_Reset()
{
	switch (g_nBonusRound)
	{
		case BonusRound_None: return;
		case BonusRound_RandomFits:
		{
			tf_weapon_criticals.Flags &= ~FCVAR_NOTIFY;
			tf_weapon_criticals.BoolValue = false;
			tf_weapon_criticals.Flags |= FCVAR_NOTIFY;
		}
		case BonusRound_TeamSwap:
		{
			TFTeam nTemp = TFTeam_Zombie;
			TFTeam_Zombie = TFTeam_Survivor;
			TFTeam_Survivor = nTemp;
		}
	}

	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient) && IsPlayerAlive(iClient))
			BonusRound_ResetClient(iClient);
	}

	g_nBonusRound = BonusRound_None;
}

void BonusRound_PlayerSpawn(int iClient)
{
	SetEntityGravity(iClient, 1.0);
	TF2Attrib_RemoveByName(iClient, "health regen");
	TF2Attrib_RemoveByName(iClient, "voice pitch scale");
	TF2Attrib_RemoveByName(iClient, "head scale");

	switch (g_nBonusRound)
	{
		case BonusRound_None: return;
		case BonusRound_LowGravity: SetEntityGravity(iClient, 0.6);
		case BonusRound_HighGravity: SetEntityGravity(iClient, 1.4);
		case BonusRound_NoDispensers:
		{
			if (IsSurvivor(iClient))
				TF2Attrib_SetByName(iClient, "health regen", 4.0);
		}
		case BonusRound_CuriousFeeling:
		{
			int iMelee = GetPlayerWeaponSlot(iClient, WeaponSlot_Melee);
			if (iMelee > MaxClients)
				TF2Attrib_SetByName(iMelee, "vision opt in flags", float(TF_VISION_FILTER_PYRO));

			TF2Attrib_SetByName(iClient, "voice pitch scale", 1.5);
			TF2Attrib_SetByName(iClient, "head scale", 0.5);
		}
		case BonusRound_MeleeBattle:
		{
			if (IsSurvivor(iClient))
			{
				TF2_SwitchActiveWeapon(iClient, GetPlayerWeaponSlot(iClient, WeaponSlot_Melee));
				TF2_RemoveWeaponSlot(iClient, WeaponSlot_Primary);
				TF2_RemoveWeaponSlot(iClient, WeaponSlot_Secondary);
			}
		}
	}
}

void BonusRound_ResetClient(int iClient)
{
	switch (g_nBonusRound)
	{
		case BonusRound_None: return;
		case BonusRound_LowGravity, BonusRound_HighGravity: SetEntityGravity(iClient, 1.0);
		case BonusRound_NoDispensers:
		{
			if (IsSurvivor(iClient))
				TF2Attrib_RemoveByName(iClient, "health regen");
		}
		case BonusRound_CuriousFeeling:
		{
			int iMelee = GetPlayerWeaponSlot(iClient, WeaponSlot_Melee);
			if (iMelee > MaxClients)
				TF2Attrib_SetByName(iMelee, "vision opt in flags", float(TF_VISION_FILTER_HALLOWEEN));

			TF2Attrib_RemoveByName(iClient, "voice pitch scale");
			TF2Attrib_RemoveByName(iClient, "head scale");
		}
	}
}