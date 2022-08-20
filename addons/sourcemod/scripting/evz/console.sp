void Console_Init()
{
	AddCommandListener(Console_JoinTeam, "jointeam");
	AddCommandListener(Console_JoinTeam, "spectate");
	AddCommandListener(Console_JoinTeam, "autoteam");
	AddCommandListener(Console_JoinClass, "joinclass");
	AddCommandListener(Console_Build, "build");
}

public Action Console_JoinTeam(int iClient, const char[] sCommand, int iArgc)
{
	if (iArgc < 1 && StrEqual(sCommand, "jointeam", false))
		return Plugin_Handled;

	if (!IsClientInGame(iClient))
		return Plugin_Continue;

	char sArg[32], sSurTeam[16], sZomTeam[16];

	if (StrEqual(sCommand, "jointeam", false))
		GetCmdArg(1, sArg, sizeof(sArg));
	else if (StrEqual(sCommand, "spectate", false))
		strcopy(sArg, sizeof(sArg), "spectate");
	else if (StrEqual(sCommand, "autoteam", false))
		strcopy(sArg, sizeof(sArg), "autoteam");

	// Waiting for players, all survivors
	if (g_nRoundState < EVZRoundState_Setup && !StrEqual(sArg, "spectate", false))
	{
		TF2_ChangeClientTeam(iClient, TFTeam_Survivor);
		TF2_RespawnPlayer2(iClient);
		return Plugin_Handled;
	}

	// Check if client is trying to skip playing as zombie by joining spectator
	if (StrEqual(sArg, "spectate", false))
		CheckZombieBypass(iClient);

	sSurTeam = (TFTeam_Zombie == TFTeam_Blue) ? "red" : "blue";
	sZomTeam = (TFTeam_Zombie == TFTeam_Blue) ? "blue" : "red";

	if (g_nRoundState == EVZRoundState_Setup)
	{
		TFTeam nTeam = TF2_GetClientTeam(iClient);

		// If a client tries to join the infected team or a random team during setup...
		if (StrEqual(sArg, sZomTeam, false) || StrEqual(sArg, "auto", false) || StrEqual(sArg, "autoteam", false))
		{
			// ...as survivor, don't let them.
			if (nTeam == TFTeam_Survivor)
			{
				CPrintToChat(iClient, "%t", "Chat_CantSwitchSetup");
				return Plugin_Handled;
			}

			// ...as a spectator who didn't start as an infected, set them as infected after setup ends, after warning them
			if (nTeam <= TFTeam_Spectator && !g_bStartedAsZombie[iClient])
			{
				if (!g_bWaitingForTeamSwitch[iClient])
				{
					if (nTeam == TFTeam_Unassigned) // If they're unassigned, let them spectate for now
						TF2_ChangeClientTeam(iClient, TFTeam_Spectator);

					CPrintToChat(iClient, "%t", "Chat_WillJoinZombieSetup");
					g_bWaitingForTeamSwitch[iClient] = true;
				}

				return Plugin_Handled;
			}	
		}
		else if (StrEqual(sArg, "spectate", false))
		{
			if (nTeam <= TFTeam_Spectator && g_bWaitingForTeamSwitch[iClient])
			{
				CPrintToChat(iClient, "%t", "Chat_CancelSetupEnd");
				g_bWaitingForTeamSwitch[iClient] = false;
			}

			return Plugin_Continue;
		}

		// If client tries to join the survivor team during setup period, 
		// deny and set them as infected instead
		else if (StrEqual(sArg, sSurTeam, false))
		{
			if (nTeam <= TFTeam_Spectator && !g_bWaitingForTeamSwitch[iClient])
			{
				if (g_bStartedAsZombie[iClient])
				{
					TF2_ChangeClientTeam(iClient, TFTeam_Zombie);
					TF2_RespawnPlayer2(iClient);
				}
				else
				{
					if (nTeam == TFTeam_Unassigned) // If they're unassigned, let them spectate for now
						TF2_ChangeClientTeam(iClient, TFTeam_Spectator);

					CPrintToChat(iClient, "%t", "Chat_CantJoinDuringSetup");
					g_bWaitingForTeamSwitch[iClient] = true;
				}
			}
		}

		return Plugin_Handled;
	}
	else if (g_nRoundState > EVZRoundState_Setup)
	{
		if (StrEqual(sArg, sZomTeam, false) || StrEqual(sArg, sSurTeam, false) || StrEqual(sArg, "auto", false))
		{
			TF2_ChangeClientTeam(iClient, TFTeam_Zombie);
			TF2_RespawnPlayer2(iClient);
			return Plugin_Handled;
		}
		else if (StrEqual(sArg, "spectate", false))
			return Plugin_Continue;

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action Console_JoinClass(int iClient, const char[] sCommand, int iArgc)
{
	if (iArgc < 1)
		return Plugin_Handled;

	char sClass[32];
	GetCmdArg(1, sClass, sizeof(sClass));

	if (IsZombie(iClient) && TF2_GetClass(sClass) == TFClass_Zombie)
		return Plugin_Continue;

	if (IsSurvivor(iClient) && TF2_GetClass(sClass) == TFClass_Survivor)
		return Plugin_Continue;

	return Plugin_Handled;
}

public Action Console_Build(int iClient, const char[] sCommand, int iArgc)
{
	if (iArgc < 1)
		return Plugin_Handled;

	char sObjectType[32];
	GetCmdArg(1, sObjectType, sizeof(sObjectType));

	TFObjectType nObjectType = view_as<TFObjectType>(StringToInt(sObjectType));
	switch (nObjectType)
	{
		case TFObject_Sentry:
		{
			if (!IsAllowedToBuildSentry(iClient))
				return Plugin_Handled;
		}
		case TFObject_Dispenser:
		{
			if (g_nBonusRound == BonusRound_NoDispensers)
				return Plugin_Handled;
		}
		case TFObject_Teleporter:
		{
			if (g_nBonusRound == BonusRound_DoubleDilemma)
				return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}