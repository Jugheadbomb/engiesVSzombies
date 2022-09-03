void Event_Init()
{
	HookEvent("teamplay_round_start", Event_RoundStart, EventHookMode_Pre);
	HookEvent("teamplay_round_win", Event_RoundEnd);

	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);
	HookEvent("post_inventory_application", Event_PostInventory);
	HookEvent("player_death", Event_PlayerDeath);

	HookEvent("object_destroyed", Event_ObjectDestroyed);
}

public void Event_RoundStart(Event event, const char[] sName, bool bDontBroadcast)
{
	g_bLastSurvivor = false;

	// Control entities
	SendEntityInput("team_control_point_master", "Disable");
	SendEntityInput("mapobj_cart_dispenser", "Disable");
	SendEntityInput("trigger_multiple", "Disable");
	SendEntityInput("trigger_capture_area", "Disable");
	SendEntityInput("func_areaportal", "Open");
	SendEntityInput("func_capturezone", "Disable");
	SendEntityInput("func_regenerate", "Disable");
	SendEntityInput("func_respawnroomvisualizer", "Disable");
	SendEntityInput("func_tracktrain", "Kill");

	int iEntity = MaxClients + 1;
	while ((iEntity = FindEntityByClassname(iEntity, "func_door")) > MaxClients)
	{
		AcceptEntityInput(iEntity, "Unlock");
		AcceptEntityInput(iEntity, "Open");
		AcceptEntityInput(iEntity, "Lock");
	}

	iEntity = MaxClients + 1;
	while ((iEntity = FindEntityByClassname(iEntity, "team_control_point")) > MaxClients)
	{
		SetVariantInt(1);
		AcceptEntityInput(iEntity, "SetLocked");
	}

	iEntity = MaxClients + 1;
	while ((iEntity = FindEntityByClassname(iEntity, "func_brush")) > MaxClients)
	{
		char sTargetName[128];
		GetEntPropString(iEntity, Prop_Data, "m_iName", sTargetName, sizeof(sTargetName));
		if (sTargetName[0] && StrContains(sTargetName, "skybox", false) == -1)
			AcceptEntityInput(iEntity, "Disable");
	}

	iEntity = FindEntityByClassname(MaxClients + 1, "team_control_point_master");
	if (iEntity > MaxClients)
	{
		SetEntProp(iEntity, Prop_Data, "m_bScorePerCapture", false);
		SetEntProp(iEntity, Prop_Data, "m_bSwitchTeamsOnWin", false);
	}

	iEntity = FindEntityByClassname(MaxClients + 1, "tf_logic_holiday");
	if (iEntity > MaxClients)
	{
		SetVariantInt(0);
		AcceptEntityInput(iEntity, "HalloweenSetUsingSpells");
	}

	if (g_nRoundState == EVZRoundState_Waiting)
		return;

	g_nRoundState = EVZRoundState_Setup;
	SendEntityInput("team_round_timer", "Kill");

	// Assign players to zombie and survivor teams
	TFTeam[] nClientTeam = new TFTeam[MaxClients + 1];
	int[] iClients = new int[MaxClients];
	int iLength = 0;
	int iSurvivorCount;

	// Find all active players
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		g_flTimeStartAsZombie[iClient] = 0.0;
		g_bUsedVest[iClient] = false;

		if (IsClientInGame(iClient) && TF2_GetClientTeam(iClient) > TFTeam_Spectator)
		{
			iClients[iLength] = iClient;
			iLength++;
		}
	}

	// Randomize, sort players
	SortIntegers(iClients, iLength, Sort_Random);

	// Calculate team counts. At least one survivor must exist
	iSurvivorCount = RoundToFloor(iLength * g_ConvarInfo.LookupFloat("evz_ratio"));
	if (iSurvivorCount == 0 && iLength > 0)
		iSurvivorCount = 1;

	for (int i = 0; i < iLength; i++)
	{
		int iClient = iClients[i];
		if (IsClientInGame(iClient))
		{
			if (g_bForceZombieStart[iClient])
			{
				// If player attempted to skip playing as zombie last time, force him to be in zombie team
				CPrintToChat(iClient, "%t", "Chat_ForceZombieStart");
				g_bForceZombieStart[iClient] = false;
				g_cForceZombieStart.Set(iClient, "0");

				SpawnClient(iClient, TFTeam_Zombie);
				nClientTeam[iClient] = TFTeam_Zombie;
				g_bStartedAsZombie[iClient] = true;
				g_flTimeStartAsZombie[iClient] = GetGameTime();
			}
			else if (g_bStartedAsZombie[iClient])
			{
				// Players who started as zombie last time is forced to be survivors
				SpawnClient(iClient, TFTeam_Survivor);
				nClientTeam[iClient] = TFTeam_Survivor;
				g_bStartedAsZombie[iClient] = false;
				iSurvivorCount--;
			}
		}
	}

	for (int i = 0; i < iLength; i++)
	{
		int iClient = iClients[i];

		// Check if they have not already been assigned
		if (IsClientInGame(iClient) && nClientTeam[iClient] != TFTeam_Zombie && nClientTeam[iClient] != TFTeam_Survivor)
		{
			if (iSurvivorCount > 0)
			{
				SpawnClient(iClient, TFTeam_Survivor);
				nClientTeam[iClient] = TFTeam_Survivor;
				g_bStartedAsZombie[iClient] = false;
				iSurvivorCount--;
			}
			else
			{
				SpawnClient(iClient, TFTeam_Zombie);
				nClientTeam[iClient] = TFTeam_Zombie;
				g_bStartedAsZombie[iClient] = true;
				g_flTimeStartAsZombie[iClient] = GetGameTime();
			}
		}
	}

	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;

		if (IsZombie(iClient))
			SetEntityMoveType(iClient, MOVETYPE_NONE);

		for (int iSlot = WeaponSlot_Primary; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
		{
			int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
			if (iWeapon == -1)
				continue;

			WeaponConfig config;
			if (WeaponConfig_GetByEntity(iWeapon, config, Value_Index))
			{
				if (config.iIndexPrefab >= 0)
					WeaponConfig_GetByItemdef(config.iIndexPrefab, config);

				if (config.sName[0] && config.sDesc[0])
					CPrintToChat(iClient, "{immortal}%t: %t", config.sName, config.sDesc);
			}

			if (WeaponConfig_GetByEntity(iWeapon, config, Value_Classname))
			{
				if (config.sName[0] && config.sDesc[0])
					CPrintToChat(iClient, "{immortal}%t: %t", config.sName, config.sDesc);
			}
		}
	}

	BonusRound_Reset();
	if (g_ConvarInfo.LookupBool("evz_bonus_rounds_enable") && GameRules_GetProp("m_nRoundsPlayed") >= 1)
	{
		if (GetURandomFloat() < g_ConvarInfo.LookupFloat("evz_bonus_rounds_chance"))
			BonusRound_StartRoll();
	}

	RequestFrame(Frame_CreateRoundTimer);
	SetGlow();
}

public void Event_RoundEnd(Event event, const char[] sName, bool bDontBroadcast)
{
	g_nRoundState = EVZRoundState_End;
	SendEntityInput("func_respawnroom", "DisableAndEndTouch");

	BonusRound_Reset();
	SetGlow();
}

public void Event_PlayerTeam(Event event, const char[] sName, bool bDontBroadcast)
{
	event.BroadcastDisabled = true;
}

public void Event_PostInventory(Event event, const char[] sName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	if (TF2_GetClientTeam(iClient) <= TFTeam_Spectator)
		return;

	g_iKillComboCount[iClient] = 0;

	ClientCommand(iClient, "r_screenoverlay\"\"");
	TF2_ResetSpeed(iClient);

	SetEntityRenderMode(iClient, RENDER_NORMAL);
	SetEntityRenderColor(iClient, 255, 255, 255);
	SetEntityMoveType(iClient, MOVETYPE_WALK);

	SetVariantString("");
	AcceptEntityInput(iClient, "SetCustomModel");

	TFClassType nClass = TF2_GetPlayerClass(iClient);

	if (IsSurvivor(iClient))
	{
		if (IsActiveRound())
		{
			SpawnClient(iClient, TFTeam_Zombie);
			return;
		}

		if (nClass != TFClass_Survivor)
		{
			TF2_RespawnPlayer2(iClient);
			return;
		}
	}
	else if (IsZombie(iClient))
	{
		if (g_nRoundState == EVZRoundState_Waiting)
		{
			SpawnClient(iClient, TFTeam_Survivor);
			return;
		}

		if (nClass != TFClass_Zombie)
		{
			TF2_RespawnPlayer2(iClient);
			return;
		}
	}

	CheckClientWeapons(iClient);
	SetEntProp(iClient, Prop_Send, "m_iPlayerSkinOverride", IsZombie(iClient) ? 1 : 0);

	// Balance specific weapons
	for (int iSlot = WeaponSlot_Primary; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
	{
		int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
		if (iWeapon == -1)
			continue;

		int iIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");

		char sClassname[64];
		GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));

		int iLength = g_aWeapons.Length;
		for (int i = 0; i < iLength; i++)
		{
			WeaponConfig config;
			g_aWeapons.GetArray(i, config, sizeof(config));

			if (StrEqual(config.sClassname, sClassname))
			{
				char sAttribs[32][32];
				int iCount = ExplodeString(config.sAttrib, " ; ", sAttribs, sizeof(sAttribs), sizeof(sAttribs));
				if (iCount > 1)
					for (int j = 0; j < iCount; j += 2)
						TF2Attrib_SetByDefIndex(iWeapon, StringToInt(sAttribs[j]), StringToFloat(sAttribs[j+1]));

				continue;
			}

			if (config.iIndex == iIndex)
			{
				// Check for prefab
				if (config.iIndexPrefab >= 0)
				{
					int iPrefab = config.iIndexPrefab;
					for (int j = 0; j < iLength; j++)
					{
						g_aWeapons.GetArray(j, config, sizeof(config));
						if (config.iIndex == iPrefab)
							break;
					}
				}

				// See if there is weapon to replace
				if (config.iIndexReplace >= 0)
				{
					iIndex = config.iIndexReplace;
					TF2_RemoveWeaponSlot(iClient, iSlot);
					iWeapon = TF2_CreateAndEquipWeapon(iClient, iIndex);
				}

				// Apply attributes
				char sAttribs[32][32];
				int iCount = ExplodeString(config.sAttrib, " ; ", sAttribs, sizeof(sAttribs), sizeof(sAttribs));
				if (iCount > 1)
					for (int j = 0; j < iCount; j += 2)
						TF2Attrib_SetByDefIndex(iWeapon, StringToInt(sAttribs[j]), StringToFloat(sAttribs[j+1]));

				break;
			}
		}

		if (iSlot == WeaponSlot_Melee)
		{
			// Allow see zombie souls
			TF2Attrib_SetByName(iWeapon, "vision opt in flags", float(TF_VISION_FILTER_HALLOWEEN));
		}

		// This will refresh health max calculation and other attributes
		TF2Attrib_ClearCache(iWeapon);
	}

	if (IsZombie(iClient))
	{
		// Zombie soul
		TF2_CreateAndEquipWeapon(iClient, GetClassVoodooDefIndex(nClass), "450 ; 1");

		if (g_nRoundState == EVZRoundState_Boost)
		{
			TF2_SetSpeed(iClient, g_ConvarInfo.LookupFloat("evz_zombie_speed_boost"));

			int iColor[4];
			if (g_ConvarInfo.LookupIntArray("evz_zombie_boost_color", iColor, sizeof(iColor)))
			{
				SetEntityRenderMode(iClient, RENDER_TRANSCOLOR);
				SetEntityRenderColor(iClient, iColor[0], iColor[1], iColor[2], iColor[3]);
			}
		}
		else if (g_nRoundState == EVZRoundState_Setup)
			SetEntityMoveType(iClient, MOVETYPE_NONE);
	}
	else if (IsSurvivor(iClient) && !IsAllowedToBuildSentry(iClient))
	{
		int iSentry = MaxClients + 1;
		while ((iSentry = FindEntityByClassname(iSentry, "obj_sentrygun")) > MaxClients)
		{
			if (GetEntPropEnt(iSentry, Prop_Send, "m_hBuilder") == iClient)
			{
				SetVariantInt(GetEntProp(iSentry, Prop_Send, "m_iHealth"));
				AcceptEntityInput(iSentry, "RemoveHealth");
			}
		}
	}

	BonusRound_PlayerSpawn(iClient);
	SetGlow();
}

public void Event_PlayerDeath(Event event, const char[] sName, bool bDontBroadcast)
{
	int iVictim = GetClientOfUserId(event.GetInt("userid"));
	if (iVictim <= 0 || iVictim > MaxClients || !IsClientInGame(iVictim))
		return;
	
	int iAttacker = GetClientOfUserId(event.GetInt("attacker"));

	if (IsZombie(iVictim))
	{
		RequestFrame(Frame_CheckZombieBypass, iVictim);

		if (iVictim != iAttacker && 0 < iAttacker <= MaxClients && IsClientInGame(iAttacker))
		{
			WeaponConfig config;
			if (WeaponConfig_GetByItemdef(event.GetInt("weapon_def_index"), config) && config.iKillComboCrit)
			{
				g_iKillComboCount[iAttacker]++;
				if (g_iKillComboCount[iAttacker] == config.iKillComboCrit)
					CPrintToChat(iAttacker, "%t", "Chat_KillComboCritCharged");
			}
		}
	}

	// Instant respawn outside of the actual gameplay
	if (g_nRoundState < EVZRoundState_Active)
	{
		CreateTimer(0.1, Timer_RespawnPlayer, iVictim);
		return;
	}

	if (IsSurvivor(iVictim))
		RequestFrame(Frame_SurvivorDeath, iVictim);

	if (iVictim != iAttacker && 0 < iAttacker <= MaxClients && IsClientInGame(iAttacker))
	{
		if (g_nBonusRound == BonusRound_MurderousJoy)
			PlayTaunt(iAttacker, 463); // 463 - laugh taunt
	}

	SetGlow();
}

public void Event_ObjectDestroyed(Event event, const char[] sName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(event.GetInt("attacker"));
	if (IsZombie(iClient) && g_nBonusRound == BonusRound_MurderousJoy)
		PlayTaunt(iClient, 463); // 463 - laugh taunt
}