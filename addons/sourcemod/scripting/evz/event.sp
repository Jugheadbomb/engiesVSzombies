void Event_Init()
{
	HookEvent("teamplay_round_start", Event_RoundStart, EventHookMode_Pre);
	HookEvent("teamplay_round_win", Event_RoundEnd);

	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);
	HookEvent("post_inventory_application", Event_PostInventory);
	HookEvent("player_death", Event_PlayerDeath);
}

void Event_RoundStart(Event event, const char[] sName, bool bDontBroadcast)
{
	g_bLastSurvivor = false;

	// Control entities
	SendEntityInput("team_control_point_master", "Disable");
	SendEntityInput("mapobj_cart_dispenser", "Disable");
	SendEntityInput("trigger_capture_area", "Disable");
	SendEntityInput("func_capturezone", "Disable");
	SendEntityInput("func_regenerate", "Disable");
	SendEntityInput("func_respawnroomvisualizer", "Disable");
	SendEntityInput("func_tracktrain", "Kill");

	int iEntity = -1;
	while ((iEntity = FindEntityByClassname(iEntity, "func_door")) != -1)
	{
		AcceptEntityInput(iEntity, "Unlock");
		AcceptEntityInput(iEntity, "Open");
	}

	iEntity = -1;
	while ((iEntity = FindEntityByClassname(iEntity, "func_brush")) != -1)
	{
		char sBrushName[32];
		GetEntPropString(iEntity, Prop_Data, "m_iName", sBrushName, sizeof(sBrushName));
		if (StrContains(sBrushName, "door", false) != -1
			|| StrContains(sBrushName, "gate", false) != -1
			|| StrContains(sBrushName, "exit", false) != -1
			|| StrContains(sBrushName, "grate", false) != -1
			|| StrContains(sBrushName, "bullet", false) != -1
			|| StrContains(sBrushName, "blocker", false) != -1)
		{
			RemoveEntity(iEntity);
		}
	}

	SendEntityInput("func_areaportal", "Open");

	iEntity = -1;
	while ((iEntity = FindEntityByClassname(iEntity, "team_control_point")) != -1)
	{
		SetVariantInt(1);
		AcceptEntityInput(iEntity, "SetLocked");
	}

	iEntity = FindEntityByClassname(-1, "team_control_point_master");
	if (iEntity > MaxClients)
	{
		SetEntProp(iEntity, Prop_Data, "m_bScorePerCapture", false);
		SetEntProp(iEntity, Prop_Data, "m_bSwitchTeamsOnWin", false);
	}

	iEntity = FindEntityByClassname(-1, "tf_logic_holiday");
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
		g_Player[iClient].flTimeStartAsZombie = 0.0;
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
			if (g_Player[iClient].bForceZombieStart)
			{
				// If player attempted to skip playing as zombie last time, force him to be in zombie team
				CPrintToChat(iClient, "%t", "Chat_ForceZombieStart");
				g_Player[iClient].bForceZombieStart = false;
				g_cForceZombieStart.Set(iClient, "0");

				SpawnClient(iClient, TFTeam_Zombie);
				nClientTeam[iClient] = TFTeam_Zombie;
				g_Player[iClient].bStartedAsZombie = true;
				g_Player[iClient].flTimeStartAsZombie = GetGameTime();
			}
			else if (g_Player[iClient].bStartedAsZombie)
			{
				// Players who started as zombie last time is forced to be survivors
				SpawnClient(iClient, TFTeam_Survivor);
				nClientTeam[iClient] = TFTeam_Survivor;
				g_Player[iClient].bStartedAsZombie = false;
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
				g_Player[iClient].bStartedAsZombie = false;
				iSurvivorCount--;
			}
			else
			{
				SpawnClient(iClient, TFTeam_Zombie);
				nClientTeam[iClient] = TFTeam_Zombie;
				g_Player[iClient].bStartedAsZombie = true;
				g_Player[iClient].flTimeStartAsZombie = GetGameTime();
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

			WeaponConfig weapon;
			if (g_WeaponList.GetByEntity(iWeapon, weapon, Value_Index))
			{
				if (weapon.iIndexPrefab >= 0)
					g_WeaponList.GetByDefIndex(weapon.iIndexPrefab, weapon);

				if (weapon.sName[0] && weapon.sDesc[0])
					CPrintToChat(iClient, "{immortal}%t: %t", weapon.sName, weapon.sDesc);
			}

			if (g_WeaponList.GetByEntity(iWeapon, weapon, Value_Classname))
			{
				if (weapon.sName[0] && weapon.sDesc[0])
					CPrintToChat(iClient, "{immortal}%t: %t", weapon.sName, weapon.sDesc);
			}
		}
	}

	BonusRound_Reset();
	if (g_ConvarInfo.LookupBool("evz_bonus_rounds_enable") && GameRules_GetProp("m_nRoundsPlayed") >= 1)
	{
		if (GetURandomFloat() < g_ConvarInfo.LookupFloat("evz_bonus_rounds_chance"))
			BonusRound_StartRoll();
	}

	CreateTimer(0.5, Timer_CreateRoundTimer);
	SetGlow();
}

void Event_RoundEnd(Event event, const char[] sName, bool bDontBroadcast)
{
	g_nRoundState = EVZRoundState_End;
	SendEntityInput("func_respawnroom", "DisableAndEndTouch");

	BonusRound_Reset();
	SetGlow();
}

void Event_PlayerTeam(Event event, const char[] sName, bool bDontBroadcast)
{
	event.BroadcastDisabled = true;
}

void Event_PostInventory(Event event, const char[] sName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	if (TF2_GetClientTeam(iClient) <= TFTeam_Spectator)
		return;

	g_Player[iClient].iKillComboCount = 0;

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

		int iLength = g_WeaponList.Length;
		for (int i = 0; i < iLength; i++)
		{
			WeaponConfig weapon;
			g_WeaponList.GetArray(i, weapon, sizeof(weapon));

			if (StrEqual(weapon.sClassname, sClassname))
			{
				char sAttribs[32][32];
				int iCount = ExplodeString(weapon.sAttrib, " ; ", sAttribs, sizeof(sAttribs), sizeof(sAttribs));
				if (iCount > 1)
					for (int j = 0; j < iCount; j += 2)
						TF2Attrib_SetByDefIndex(iWeapon, StringToInt(sAttribs[j]), StringToFloat(sAttribs[j+1]));

				continue;
			}

			if (weapon.iIndex == iIndex)
			{
				// Check for prefab
				if (weapon.iIndexPrefab >= 0)
				{
					int iPrefab = weapon.iIndexPrefab;
					for (int j = 0; j < iLength; j++)
					{
						g_WeaponList.GetArray(j, weapon, sizeof(weapon));
						if (weapon.iIndex == iPrefab)
							break;
					}
				}

				// See if there is weapon to replace
				if (weapon.iIndexReplace >= 0)
				{
					iIndex = weapon.iIndexReplace;
					TF2_RemoveWeaponSlot(iClient, iSlot);
					iWeapon = TF2_CreateAndEquipWeapon(iClient, iIndex);
				}

				// Apply attributes
				char sAttribs[32][32];
				int iCount = ExplodeString(weapon.sAttrib, " ; ", sAttribs, sizeof(sAttribs), sizeof(sAttribs));
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

		int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
		if (iAmmoType > -1)
		{
			// Reset ammo before GivePlayerAmmo gives back properly
			SetEntProp(iClient, Prop_Send, "m_iAmmo", 0, _, iAmmoType);
			GivePlayerAmmo(iClient, 9999, iAmmoType, true);
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

				int iSoul = GetVoodooSoul(iClient);
				if (iSoul > MaxClients)
				{
					SetEntityRenderMode(iSoul, RENDER_TRANSCOLOR);
					SetEntityRenderColor(iSoul, iColor[0], iColor[1], iColor[2], iColor[3]);
				}
			}
		}
		else if (g_nRoundState == EVZRoundState_Setup)
			SetEntityMoveType(iClient, MOVETYPE_NONE);
	}
	else if (IsSurvivor(iClient) && !IsAllowedToBuildSentry(iClient))
	{
		int iSentry = -1;
		while ((iSentry = FindEntityByClassname(iSentry, "obj_sentrygun")) != -1)
		{
			if (GetEntPropEnt(iSentry, Prop_Send, "m_hBuilder") == iClient)
			{
				SetVariantInt(GetEntProp(iSentry, Prop_Send, "m_iHealth"));
				AcceptEntityInput(iSentry, "RemoveHealth");
			}
		}
	}

	// Santa hat
	if (TF2_IsHolidayActive(TFHoliday_Christmas))
		TF2_CreateAndEquipWeapon(iClient, SANTA_HAT);

	BonusRound_PlayerSpawn(iClient);
	SetGlow();
}

void Event_PlayerDeath(Event event, const char[] sName, bool bDontBroadcast)
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
			WeaponConfig weapon;
			if (g_WeaponList.GetByDefIndex(event.GetInt("weapon_def_index"), weapon) && weapon.iKillComboCrit)
			{
				g_Player[iAttacker].iKillComboCount++;
				if (g_Player[iAttacker].iKillComboCount == weapon.iKillComboCrit)
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

	SetGlow();
}