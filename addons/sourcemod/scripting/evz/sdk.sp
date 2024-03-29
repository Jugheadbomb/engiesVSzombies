static Handle g_hSDKEquipWearable;
static Handle g_hSDKSetSpeed;
static DynamicHook g_DHookShouldTransmit;
static TFTeam g_nOldClientTeam[MAXPLAYERS];

void SDK_Init()
{
	GameData hTF2 = new GameData("sm-tf2.games");
	if (!hTF2)
		SetFailState("Could not find sm-tf2.games.txt gamedata!");

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetVirtual(hTF2.GetOffset("RemoveWearable") - 1);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	if (!(g_hSDKEquipWearable = EndPrepSDKCall()))
		LogError("Failed to create call: CBasePlayer::EquipWearable!");

	GameData hEVZ = new GameData("evz");
	if (!hEVZ)
		SetFailState("Could not find evz.txt gamedata!");

	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hEVZ, SDKConf_Signature, "CTFPlayer::TeamFortress_SetSpeed");
	if (!(g_hSDKSetSpeed = EndPrepSDKCall()))
		LogError("Failed to create call: CTFPlayer::TeamFortress_SetSpeed");

	g_DHookShouldTransmit = DynamicHook.FromConf(hEVZ, "CBaseEntity::ShouldTransmit");
	DynamicDetour.FromConf(hEVZ, "CTFWeaponBaseMelee::DoSwingTraceInternal").Enable(Hook_Pre, DHook_DoSwingTraceInternalPre);
	DynamicDetour.FromConf(hEVZ, "CTFWeaponBaseMelee::DoSwingTraceInternal").Enable(Hook_Post, DHook_DoSwingTraceInternalPost);
	DynamicDetour.FromConf(hEVZ, "CTFAmmoPack::MakeHolidayPack").Enable(Hook_Pre, DHook_MakeHolidayPackPre);

	delete hTF2;
	delete hEVZ;
}

void SDK_OnClientConnect(int iClient)
{
	g_DHookShouldTransmit.HookEntity(Hook_Post, iClient, DHook_ShouldTransmitPost);
}

MRESReturn DHook_ShouldTransmitPost(int iClient, DHookReturn ret, DHookParam params)
{
	if (GetEntProp(iClient, Prop_Send, "m_bGlowEnabled"))
	{
		ret.Value = FL_EDICT_ALWAYS;
		return MRES_Supercede;
	}

	return MRES_Ignored;
}

MRESReturn DHook_MakeHolidayPackPre(int iAmmoPack)
{
	// Disable halloween pumpkins
	return (TF2_IsHolidayActive(TFHoliday_Halloween)) ? MRES_Supercede : MRES_Ignored;
}

MRESReturn DHook_DoSwingTraceInternalPre(int iMelee, DHookReturn ret, DHookParam params)
{
	if (!ConvarInfo.LookupBool("evz_melee_ignores_teammates"))
		return MRES_Ignored;

	// Enable MvM for this function for melee trace hack
	GameRules_SetProp("m_bPlayingMannVsMachine", true);

	int iOwner = GetEntPropEnt(iMelee, Prop_Send, "m_hOwnerEntity");
	TFTeam nOwnerTeam = TF2_GetClientTeam(iOwner);

	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsClientInGame(iClient))
			continue;

		// Save current team for later
		TFTeam nTeam = TF2_GetClientTeam(iClient);
		g_nOldClientTeam[iClient] = nTeam;

		// Melee trace ignores teammates for MvM invaders
		// Move teammates to the BLU team and enemies to the RED team
		SetEntProp(iClient, Prop_Data, "m_iTeamNum", nTeam == nOwnerTeam ? TFTeam_Blue : TFTeam_Red);
	}

	return MRES_Ignored;
}

MRESReturn DHook_DoSwingTraceInternalPost(int iMelee, DHookReturn ret, DHookParam params)
{
	if (!ConvarInfo.LookupBool("evz_melee_ignores_teammates"))
		return MRES_Ignored;

	// Disable MvM so there are no lingering effects
	GameRules_SetProp("m_bPlayingMannVsMachine", false);

	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsClientInGame(iClient))
			continue;

		// Restore client's previous team
		SetEntProp(iClient, Prop_Data, "m_iTeamNum", g_nOldClientTeam[iClient]);
	}

	return MRES_Ignored;
}

void SDK_EquipWearable(int iClient, int iWearable)
{
	SDKCall(g_hSDKEquipWearable, iClient, iWearable);
}

void SDK_SetSpeed(int iClient)
{
	SDKCall(g_hSDKSetSpeed, iClient);
}