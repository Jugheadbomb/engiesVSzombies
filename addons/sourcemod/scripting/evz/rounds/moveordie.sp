public bool MoveOrDie_OnStart(BonusRound round)
{
	if (!round.data)
		return false;

	return true;
}

public Action MoveOrDie_OnPlayerRunCmd(BonusRound round, int iClient, int &iButtons, int &iWeapon)
{
	static float flLastDamageTime[MAXPLAYERS];

	float flDamage = round.data.GetFloat("damage");
	float flInterval = round.data.GetFloat("interval");

	float vecVel[3];
	GetEntPropVector(iClient, Prop_Data, "m_vecAbsVelocity", vecVel);
	if (GetVectorLength(vecVel) == 0.0 && flLastDamageTime[iClient] < GetGameTime())
	{
		SDKHooks_TakeDamage(iClient, iClient, iClient, flDamage);
		flLastDamageTime[iClient] = GetGameTime() + flInterval;
	}

	return Plugin_Continue;
}