public bool TeamSwap_OnStart(BonusRound round)
{
	TFTeam nTemp = TFTeam_Zombie;
	TFTeam_Zombie = TFTeam_Survivor;
	TFTeam_Survivor = nTemp;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i))
			continue;

		SpawnClient(i, IsSurvivor(i) ? TFTeam_Zombie : TFTeam_Survivor);
	}

	return true;
}

public void TeamSwap_OnEnd(BonusRound round)
{
	TFTeam nTemp = TFTeam_Zombie;
	TFTeam_Zombie = TFTeam_Survivor;
	TFTeam_Survivor = nTemp;
}