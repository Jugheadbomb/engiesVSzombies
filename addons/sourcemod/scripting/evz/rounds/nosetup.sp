public bool NoSetup_OnStart(BonusRound round)
{
	int iTimer = FindEntityByClassname(-1, "team_round_timer");
	if (iTimer > MaxClients)
	{
		SetVariantInt(1);
		AcceptEntityInput(iTimer, "SetSetupTime");
	}

	return true;
}