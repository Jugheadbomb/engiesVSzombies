static int g_iVoodooIndex[view_as<int>(TFClass_Engineer) + 1] = {-1, 5617, 5625, 5618, 5620, 5622, 5619, 5624, 5623, 5621};

bool IsActiveRound()
{
	return (EVZRoundState_Setup < g_nRoundState < EVZRoundState_End);
}

bool IsSurvivor(int iClient)
{
	return (TF2_GetClientTeam(iClient) == TFTeam_Survivor);
}

bool IsZombie(int iClient)
{
	return (TF2_GetClientTeam(iClient) == TFTeam_Zombie);
}

void TF2_SwitchActiveWeapon(int iClient, int iWeapon)
{
	char sClassname[64];
	GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
	FakeClientCommand(iClient, "use %s", sClassname);
}

void TF2_SetSpeed(int iClient, float flSpeed)
{
	float flMaxspeed = GetEntPropFloat(iClient, Prop_Send, "m_flMaxspeed");
	TF2Attrib_SetByName(iClient, "move speed bonus", flSpeed / flMaxspeed);
	SDK_SetSpeed(iClient);
}

void TF2_ResetSpeed(int iClient)
{
	TF2Attrib_RemoveByName(iClient, "move speed bonus");
	SDK_SetSpeed(iClient);
}

void TF2_RespawnPlayer2(int iClient)
{
	TFClassType nClass = TF2_GetPlayerClass(iClient);

	if (IsZombie(iClient) && nClass != TFClass_Zombie)
		TF2_SetPlayerClass(iClient, TFClass_Zombie);

	if (IsSurvivor(iClient) && nClass != TFClass_Survivor)
		TF2_SetPlayerClass(iClient, TFClass_Survivor);

	TF2_RespawnPlayer(iClient);
}

int TF2_CreateAndEquipWeapon(int iClient, int iIndex, const char[] sAttribs = "")
{
	char sClassname[64];
	TF2Econ_GetItemClassName(iIndex, sClassname, sizeof(sClassname));
	TF2Econ_TranslateWeaponEntForClass(sClassname, sizeof(sClassname), TF2_GetPlayerClass(iClient));

	int iWeapon = CreateEntityByName(sClassname);
	SetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex", iIndex);
	SetEntProp(iWeapon, Prop_Send, "m_bInitialized", true);
	SetEntProp(iWeapon, Prop_Send, "m_iEntityQuality", 0);
	SetEntProp(iWeapon, Prop_Send, "m_iEntityLevel", 1);

	if (sAttribs[0])
	{
		char sAttribs2[32][32];
		int iCount = ExplodeString(sAttribs, " ; ", sAttribs2, 32, 32);
		if (iCount > 1)
			for (int i = 0; i < iCount; i += 2)
				TF2Attrib_SetByDefIndex(iWeapon, StringToInt(sAttribs2[i]), StringToFloat(sAttribs2[i+1]));
	}

	DispatchSpawn(iWeapon);
	SetEntProp(iWeapon, Prop_Send, "m_bValidatedAttachedEntity", true);

	if (StrContains(sClassname, "tf_wearable") == 0)
		SDK_EquipWearable(iClient, iWeapon);
	else
		EquipPlayerWeapon(iClient, iWeapon);

	return iWeapon;
}

void TF2_EndRound(TFTeam nTeam)
{
	int iIndex = CreateEntityByName("game_round_win");

	DispatchKeyValue(iIndex, "force_map_reset", "1");
	DispatchKeyValue(iIndex, "switch_teams", "0");
	DispatchSpawn(iIndex);

	SetVariantInt(view_as<int>(nTeam));
	AcceptEntityInput(iIndex, "SetTeam");
	AcceptEntityInput(iIndex, "RoundWin");
}

void SendEntityInput(const char[] sClassname, const char[] sInput)
{
	int iIndex = -1;
	while ((iIndex = FindEntityByClassname(iIndex, sClassname)) != -1)
		AcceptEntityInput(iIndex, sInput);
}

void SpawnClient(int iClient, TFTeam nTeam)
{
	if (!IsSurvivor(iClient) && !IsZombie(iClient))
		return;

	TFClassType nClass = TF2_GetPlayerClass(iClient);

	if (nTeam == TFTeam_Zombie && nClass != TFClass_Zombie)
		nClass = TFClass_Zombie;

	if (nTeam == TFTeam_Survivor && nClass != TFClass_Survivor)
		nClass = TFClass_Survivor;

	SetEntProp(iClient, Prop_Send, "m_lifeState", 2);
	TF2_SetPlayerClass(iClient, nClass);
	TF2_ChangeClientTeam(iClient, nTeam);
	SetEntProp(iClient, Prop_Send, "m_lifeState", 0);

	TF2_RespawnPlayer(iClient);
}

void CheckClientWeapons(int iClient)
{
	// Weapons
	for (int iSlot = WeaponSlot_Primary; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
	{
		int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
		if (iWeapon > MaxClients)
		{
			if (OnGiveNamedItem(iClient, GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex")) >= Plugin_Handled)
				TF2_RemoveWeaponSlot(iClient, iSlot);
		}
	}

	// Cosmetics
	int iWearable = -1;
	while ((iWearable = FindEntityByClassname(iWearable, "tf_wearable*")) != -1)
	{
		if (GetEntPropEnt(iWearable, Prop_Send, "m_hOwnerEntity") == iClient || GetEntPropEnt(iWearable, Prop_Send, "moveparent") == iClient)
		{
			if (OnGiveNamedItem(iClient, GetEntProp(iWearable, Prop_Send, "m_iItemDefinitionIndex")) >= Plugin_Handled)
				TF2_RemoveWearable(iClient, iWearable);
		}
	}
}

int GetVoodooSoul(int iClient)
{
	int iWearable = -1;
	while ((iWearable = FindEntityByClassname(iWearable, "tf_wearable")) != -1)
	{
		if (GetEntPropEnt(iWearable, Prop_Send, "m_hOwnerEntity") == iClient)
		{
			if (GetEntProp(iWearable, Prop_Send, "m_iItemDefinitionIndex") == GetClassVoodooDefIndex(TF2_GetPlayerClass(iClient)))
				return iWearable;
		}
	}

	return -1;
}

int GetClassVoodooDefIndex(TFClassType nClass)
{
	return g_iVoodooIndex[view_as<int>(nClass)];
}

void TF2_GetClassName(TFClassType nClass, char[] sBuffer, int iLength)
{
	switch (nClass)
	{
		case TFClass_Unknown: strcopy(sBuffer, iLength, "unknown");
		case TFClass_Scout: strcopy(sBuffer, iLength, "scout");
		case TFClass_Sniper: strcopy(sBuffer, iLength, "sniper");
		case TFClass_Soldier: strcopy(sBuffer, iLength, "soldier");
		case TFClass_DemoMan: strcopy(sBuffer, iLength, "demoman");
		case TFClass_Medic: strcopy(sBuffer, iLength, "medic");
		case TFClass_Heavy: strcopy(sBuffer, iLength, "heavy");
		case TFClass_Pyro:strcopy(sBuffer, iLength, "pyro");
		case TFClass_Spy: strcopy(sBuffer, iLength, "spy");
		case TFClass_Engineer: strcopy(sBuffer, iLength, "engineer");
	}
}

bool IsAllowedToBuildSentry(int iClient)
{
	for (int iSlot = WeaponSlot_Primary; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
	{
		int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
		if (iWeapon == -1)
			continue;

		WeaponConfig weapon;
		if (g_WeaponList.GetByEntity(iWeapon, weapon, Value_Classname) && weapon.bSentry)
			return true;

		if (g_WeaponList.GetByEntity(iWeapon, weapon, Value_Index) && weapon.bSentry)
			return true;
	}

	return false;
}

int GetPlayerCount(TFTeam nTeam = TFTeam_Unassigned, bool bAlive = false)
{
	int iCount = 0;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsClientInGame(iClient) || (bAlive && !IsPlayerAlive(iClient)))
			continue;

		iCount += (nTeam == TFTeam_Unassigned) ? 1 : (TF2_GetClientTeam(iClient) == nTeam) ? 1 : 0;
	}

	return iCount;
}

void SetTeamRespawnTime(TFTeam nTeam, float flTime)
{
	int iEntity = FindEntityByClassname(-1, "tf_gamerules");
	if (iEntity > MaxClients)
	{
		SetVariantFloat(flTime);
		switch (nTeam)
		{
			case TFTeam_Blue: AcceptEntityInput(iEntity, "SetBlueTeamRespawnWaveTime");
			case TFTeam_Red: AcceptEntityInput(iEntity, "SetRedTeamRespawnWaveTime");
		}
	}
}

void PrepareSound(const char[] sSound)
{
	PrecacheSound(sSound, true);
	char sBuffer[PLATFORM_MAX_PATH];
	Format(sBuffer, sizeof(sBuffer), "sound/%s", sSound);
	AddFileToDownloadsTable(sBuffer);
}

void AddVision(int iClient, int iFlag)
{
	float flVal = 0.0;

	Address pAttrib = TF2Attrib_GetByDefIndex(iClient, ATTRIB_VISION);
	if (pAttrib)
		flVal = TF2Attrib_GetValue(pAttrib);

	flVal = float(RoundToNearest(flVal) | iFlag);
	TF2Attrib_SetByDefIndex(iClient, ATTRIB_VISION, flVal);
}

void RemoveVision(int iClient, int iFlag)
{
	float flVal = 0.0;

	Address pAttrib = TF2Attrib_GetByDefIndex(iClient, ATTRIB_VISION);
	if (pAttrib)
	{
		flVal = TF2Attrib_GetValue(pAttrib);
		flVal = float(RoundToNearest(flVal) & ~iFlag);
		TF2Attrib_SetByDefIndex(iClient, ATTRIB_VISION, flVal);
	}
}

void TE_Particle(int iEntity, const char[] sParticle, bool bAttach)
{
	static int iTable = INVALID_STRING_TABLE;
	if (iTable == INVALID_STRING_TABLE)
		iTable = FindStringTable("ParticleEffectNames");

	TE_Start("TFParticleEffect");
	TE_WriteNum("entindex", iEntity);
	TE_WriteNum("m_iParticleSystemIndex", FindStringIndex(iTable, sParticle));
	TE_WriteNum("m_iAttachType", view_as<int>(bAttach));
	TE_SendToAll();
}