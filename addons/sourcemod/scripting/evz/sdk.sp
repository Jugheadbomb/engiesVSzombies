static Handle g_hSDKEquipWearable;
static Handle g_hSDKSetSpeed;
static Handle g_hSDKGetMaxAmmo;
static DynamicHook g_DHookShouldTransmit;
static DynamicHook g_DHookCanBeUpgraded;
static TFTeam g_nOldClientTeam[TF_MAXPLAYERS];

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

	// This call gets the weapon max ammo
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hEVZ, SDKConf_Signature, "CTFPlayer::GetMaxAmmo");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if (!(g_hSDKGetMaxAmmo = EndPrepSDKCall()))
		LogMessage("Failed to create call: CTFPlayer::GetMaxAmmo!");

	g_DHookShouldTransmit = DynamicHook.FromConf(hEVZ, "CBaseEntity::ShouldTransmit");
	g_DHookCanBeUpgraded = DynamicHook.FromConf(hEVZ, "CBaseObject::CanBeUpgraded");
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

void SDK_OnEntityCreated(int iEntity, const char[] sClassname)
{
	if (StrContains(sClassname, "obj_", false) == 0)
		g_DHookCanBeUpgraded.HookEntity(Hook_Post, iEntity, DHook_CanBeUpgradedPost);
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

MRESReturn DHook_CanBeUpgradedPost(int iBuilding, DHookReturn ret, DHookParam params)
{
	if (g_nBonusRound == BonusRound_NoUpgrades)
	{
		ret.Value = false;
		return MRES_Supercede;
	}

	return MRES_Ignored;
}

MRESReturn DHook_MakeHolidayPackPre(int iAmmoPack)
{
	return (TF2_IsHolidayActive(TFHoliday_Christmas)) ? MRES_Ignored : MRES_Supercede;
}

MRESReturn DHook_DoSwingTraceInternalPre(int iMelee, DHookReturn ret, DHookParam params)
{
	if (!g_ConvarInfo.LookupBool("evz_melee_ignores_teammates"))
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
	if (!g_ConvarInfo.LookupBool("evz_melee_ignores_teammates"))
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

int SDK_GetMaxAmmo(int iClient, int iAmmoType)
{
	return SDKCall(g_hSDKGetMaxAmmo, iClient, iAmmoType, -1);
}