public bool NoDispensers_OnStart(BonusRound round)
{
	if (!round.data)
		return false;

	SendEntityInput("obj_dispenser", "Kill");

	float flRegen = round.data.GetFloat("health regen");
	if (flRegen)
	{
		for (int i = 1; i <= MaxClients; i++)
			if (IsClientInGame(i) && IsSurvivor(i))
				TF2Attrib_SetByName(i, "health regen", flRegen);
	}

	return true;
}

public void NoDispensers_OnEnd(BonusRound round)
{
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
			TF2Attrib_RemoveByName(i, "health regen");
}

public void NoDispensers_OnPlayerSpawn(BonusRound round, int iClient)
{
	float flRegen = round.data.GetFloat("health regen");
	if (flRegen && IsSurvivor(iClient))
		TF2Attrib_SetByName(iClient, "health regen", flRegen);
}

public bool NoDispensers_IsAllowedToBuild(BonusRound round, int iClient, TFObjectType type, bool bDefault)
{
	if (type == TFObject_Dispenser && IsSurvivor(iClient))
		return false;

	return bDefault;
}