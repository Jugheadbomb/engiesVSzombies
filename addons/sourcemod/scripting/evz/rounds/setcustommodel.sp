public bool SetCustomModel_OnStart(BonusRound round)
{
	if (!round.data)
		return false;

	char sModel[PLATFORM_MAX_PATH];
	round.data.GetString("model", sModel, sizeof(sModel));

	if (!FileExists(sModel, true, "GAME") && !FileExists(sModel, true, "MOD"))
		return false;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;

		SetVariantString(sModel);
		AcceptEntityInput(i, "SetCustomModelWithClassAnimations");
	}

	return true;
}

public void SetCustomModel_OnEnd(BonusRound round)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;

		SetVariantString("");
		AcceptEntityInput(i, "SetCustomModel");
	}
}

public void SetCustomModel_OnPlayerSpawn(BonusRound round, int iClient)
{
	char sModel[PLATFORM_MAX_PATH];
	round.data.GetString("model", sModel, sizeof(sModel));

	SetVariantString(sModel);
	AcceptEntityInput(iClient, "SetCustomModelWithClassAnimations");
}