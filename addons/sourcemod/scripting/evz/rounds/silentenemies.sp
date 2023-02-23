public Action SilentEnemies_OnSoundPlayed(BonusRound round, int iClients[MAXPLAYERS], int &iNumClients, char sSound[PLATFORM_MAX_PATH], int &iEntity, int &iChannel, float &flVolume, int &iLevel, int &iPitch, int &iFlags, char sSoundEntry[PLATFORM_MAX_PATH], int &iSeed)
{
	if (iEntity <= 0 || iEntity > MaxClients || !IsClientInGame(iEntity))
		return Plugin_Continue;

	Action action = Plugin_Continue;
	for (int i = iNumClients - 1; i >= 0; i--)
	{
		if (TF2_GetEnemyTeam(TF2_GetClientTeam(iClients[i])) == TF2_GetClientTeam(iEntity))
		{
			for (int j = i; j < iNumClients; j++)
				iClients[j] = iClients[j + 1];

			iNumClients--;
			action = Plugin_Changed;
		}
	}

	return action;
}

static TFTeam TF2_GetEnemyTeam(TFTeam team)
{
	switch (team)
	{
		case TFTeam_Red: return TFTeam_Blue;
		case TFTeam_Blue: return TFTeam_Red;
		default: return team;
	}
}