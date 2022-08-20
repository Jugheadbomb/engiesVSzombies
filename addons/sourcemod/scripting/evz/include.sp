static GlobalForward g_hForwardZombiesBoost;
static GlobalForward g_hForwardZombiesRelease;
static GlobalForward g_hForwardLastSurvivor;

void Include_AskLoad()
{
	CreateNative("EVZ_GetSurvivorTeam", Native_GetSurvivorTeam);
	CreateNative("EVZ_GetZombieTeam", Native_GetZombieTeam);
	CreateNative("EVZ_GetBonusRound", Native_GetBonusRound);

	g_hForwardZombiesBoost = new GlobalForward("EVZ_OnZombiesBoost", ET_Ignore);
	g_hForwardZombiesRelease = new GlobalForward("EVZ_OnZombiesRelease", ET_Ignore);
	g_hForwardLastSurvivor = new GlobalForward("EVZ_OnLastSurvivor", ET_Ignore, Param_Cell);
}

public any Native_GetSurvivorTeam(Handle hPlugin, int iNumParams)
{
	return TFTeam_Survivor;
}

public any Native_GetZombieTeam(Handle hPlugin, int iNumParams)
{
	return TFTeam_Zombie;
}

public any Native_GetBonusRound(Handle hPlugin, int iNumParams)
{
	return g_nBonusRound;
}

void Forward_OnZombiesRelease()
{
	Call_StartForward(g_hForwardZombiesRelease);
	Call_Finish();
}

void Forward_OnZombiesBoost()
{
	Call_StartForward(g_hForwardZombiesBoost);
	Call_Finish();
}

void Forward_OnLastSurvivor(int iClient)
{
	Call_StartForward(g_hForwardLastSurvivor);
	Call_PushCell(iClient);
	Call_Finish();
}