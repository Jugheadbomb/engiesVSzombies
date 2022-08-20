#define CONFIG_WEAPONS "configs/evz/weapons.cfg"
#define CONFIG_ROUNDS "configs/evz/bonusrounds.cfg"

enum
{
	Value_Index = 0,
	Value_Classname
};

enum struct WeaponConfig
{
	int iIndex;
	int iIndexPrefab;
	int iIndexReplace;
	int iKillComboCrit;
	bool bBlockSecondary;
	bool bSentry;

	char sClassname[64];
	char sName[64];
	char sDesc[64];
	char sAttrib[256];
	char sAttribSwitch[256];

	bool ReadFromKv(KeyValues kv)
	{
		char sBuffer[64];
		kv.GetSectionName(sBuffer, sizeof(sBuffer));

		int iIndex = -1;
		if (StringToIntEx(sBuffer, iIndex) == 0)
			strcopy(this.sClassname, sizeof(WeaponConfig::sClassname), sBuffer);
		else
			this.iIndex = iIndex;

		if (this.iIndex == -1 && !this.sClassname[0])
			return false;

		this.iIndexPrefab = kv.GetNum("prefab", -1);
		this.iIndexReplace = kv.GetNum("replace", -1);
		this.iKillComboCrit = kv.GetNum("kill_combo_crit");
		this.bBlockSecondary = !!kv.GetNum("block_m2");
		this.bSentry = !!kv.GetNum("sentry");

		kv.GetString("name", this.sName, sizeof(WeaponConfig::sName));
		kv.GetString("desc", this.sDesc, sizeof(WeaponConfig::sDesc));
		kv.GetString("attrib", this.sAttrib, sizeof(WeaponConfig::sAttrib));
		kv.GetString("attrib_onswitch", this.sAttribSwitch, sizeof(WeaponConfig::sAttribSwitch));
		return (this.sName[0] && this.sDesc[0]);
	}
}

enum struct RoundConfig
{
	BonusRound id;

	char sName[64];
	char sDesc[64];

	bool ReadFromKv(KeyValues kv)
	{
		char sBuffer[64];
		kv.GetSectionName(sBuffer, sizeof(sBuffer));

		if (!kv.GetNum("enable", 1))
			return false;

		int id = -1;
		if (StringToIntEx(sBuffer, id) == 0)
			return false;

		this.id = view_as<BonusRound>(id);
		if (this.id <= BonusRound_None || this.id >= BonusRound_Count)
			return false;

		kv.GetString("name", this.sName, sizeof(RoundConfig::sName));
		kv.GetString("desc", this.sDesc, sizeof(RoundConfig::sDesc));
		return (this.sName[0] && this.sDesc[0]);
	}
}

ArrayList g_aWeapons;
ArrayList g_aRounds;

void Config_Init()
{
	g_aWeapons = new ArrayList(sizeof(WeaponConfig));
	g_aRounds = new ArrayList(sizeof(RoundConfig));
}

void Config_Refresh()
{
	Config_LoadWeapons();
	Config_LoadRounds();
}

void Config_LoadWeapons()
{
	g_aWeapons.Clear();

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_WEAPONS);

	KeyValues kv = new KeyValues("Weapons");
	if (kv.ImportFromFile(sPath) && kv.GotoFirstSubKey())
	{
		do
		{
			WeaponConfig config;
			if (config.ReadFromKv(kv))
				g_aWeapons.PushArray(config);
		}
		while (kv.GotoNextKey());
	}

	delete kv;
}

void Config_LoadRounds()
{
	g_aRounds.Clear();

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_ROUNDS);

	KeyValues kv = new KeyValues("BonusRounds");
	if (kv.ImportFromFile(sPath) && kv.GotoFirstSubKey())
	{
		do
		{
			RoundConfig config;
			if (config.ReadFromKv(kv))
				g_aRounds.PushArray(config);
		}
		while (kv.GotoNextKey());
	}

	delete kv;
}

bool WeaponConfig_GetByItemdef(int itemdef, WeaponConfig config)
{
	int index = g_aWeapons.FindValue(itemdef, WeaponConfig::iIndex);
	if (index != -1)
		return !!g_aWeapons.GetArray(index, config, sizeof(config));

	return false;
}

bool WeaponConfig_GetByEntity(int iWeapon, WeaponConfig config, int iFindVal)
{
	if (iFindVal == Value_Index)
	{
		int index = g_aWeapons.FindValue(GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex"), WeaponConfig::iIndex);
		if (index != -1)
			return !!g_aWeapons.GetArray(index, config, sizeof(config));

		return false;
	}

	char sClassname[64];
	GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));

	for (int i = 0; i < g_aWeapons.Length; i++)
	{
		if (!g_aWeapons.GetArray(i, config, sizeof(config)))
			continue;

		if (StrEqual(config.sClassname, sClassname, false))
			return true;
	}

	return false;
}

bool RoundConfig_GetRandom(RoundConfig config)
{
	if (g_aRounds.Length > 0)
		return !!g_aRounds.GetArray(GetURandomInt() % g_aRounds.Length, config, sizeof(config));

	return false;
}

bool RoundConfig_GetCurrent(RoundConfig config)
{
	if (g_nBonusRound == BonusRound_None)
		return false;

	int index = g_aRounds.FindValue(g_nBonusRound, RoundConfig::id);
	if (index != -1)
		return !!g_aRounds.GetArray(index, config, sizeof(config));

	return false;
}