#define CONFIG_PATH "configs/evz.cfg"

enum struct WeaponConfig
{
	int iIndex;
	char sClassname[64];

	char sName[64];
	char sDesc[64];
	char sAttrib[256];
	char sAttribSwitch[256];

	int iIndexPrefab;
	int iIndexReplace;
	int iKillComboCrit;
	bool bBlockSecondary;
	bool bSentry;

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

void Config_Init()
{
	g_WeaponList = new WeaponList();
	g_RoundList = new RoundList();
}

void Config_Refresh()
{
	KeyValues kv = Config_LoadFile(CONFIG_PATH);
	if (!kv)
		return;

	g_WeaponList.LoadSection(kv);
	g_RoundList.LoadSection(kv);
	g_ConvarInfo.LoadSection(kv);
	delete kv;
}

KeyValues Config_LoadFile(const char[] configFile)
{
	char configPath[PLATFORM_MAX_PATH];

	BuildPath(Path_SM, configPath, sizeof(configPath), configFile);
	if (!FileExists(configPath))
	{
		LogMessage("Failed to load config file (file missing): %s!", configPath);
		return null;
	}

	KeyValues kv = new KeyValues("Config");
	kv.SetEscapeSequences(true);

	if (!kv.ImportFromFile(configPath))
	{
		LogMessage("Failed to parse config file: %s!", configPath);
		delete kv;
		return null;
	}

	return kv;
}