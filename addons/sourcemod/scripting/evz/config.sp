#define CONFIG_PATH "configs/evz.cfg"

enum FindValue
{
	Value_Index = 0,
	Value_Classname
};

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

methodmap WeaponList < ArrayList
{
	public WeaponList()
	{
		return view_as<WeaponList>(new ArrayList(sizeof(WeaponConfig)));
	}

	public void LoadSection(KeyValues kv)
	{
		if (kv.JumpToKey("weapons", false))
		{
			if (kv.GotoFirstSubKey())
			{
				do
				{
					WeaponConfig weapon;
					if (weapon.ReadFromKv(kv))
						this.PushArray(weapon, sizeof(weapon));
				}
				while (kv.GotoNextKey());
				kv.GoBack();
			}
			kv.GoBack();
		}
	}

	public bool GetByEntity(int iWeapon, WeaponConfig weapon, FindValue findval)
	{
		switch (findval)
		{
			case Value_Index:
			{
				int index = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
				return this.GetByDefIndex(index, weapon);
			}
			case Value_Classname:
			{
				char sClassname[64];
				GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
				return this.GetByClassname(sClassname, weapon);
			}
		}

		return false;
	}

	public bool GetByDefIndex(int index, WeaponConfig weapon)
	{
		int i = this.FindValue(index, WeaponConfig::iIndex);
		if (i != -1)
			return !!this.GetArray(i, weapon);

		return false;
	}

	public bool GetByClassname(const char[] sClassname, WeaponConfig weapon)
	{
		for (int i = 0; i < this.Length; i++)
		{
			if (!this.GetArray(i, weapon, sizeof(weapon)))
				continue;

			if (StrEqual(weapon.sClassname, sClassname, false))
				return true;
		}

		return false;
	}
}

methodmap RoundList < ArrayList
{
	public RoundList()
	{
		return view_as<RoundList>(new ArrayList(sizeof(RoundConfig)));
	}

	public void LoadSection(KeyValues kv)
	{
		if (kv.JumpToKey("bonusrounds", false))
		{
			if (kv.GotoFirstSubKey())
			{
				do
				{
					RoundConfig round;
					if (round.ReadFromKv(kv))
						this.PushArray(round, sizeof(round));
				}
				while (kv.GotoNextKey());
				kv.GoBack();
			}
			kv.GoBack();
		}
	}

	public bool GetRandom(RoundConfig round)
	{
		if (this.Length > 0)
			return !!this.GetArray(GetURandomInt() % this.Length, round, sizeof(round));

		return false;
	}

	public bool GetCurrent(RoundConfig round)
	{
		if (g_nBonusRound == BonusRound_None)
			return false;

		int index = this.FindValue(g_nBonusRound, RoundConfig::id);
		if (index != -1)
			return !!this.GetArray(index, round, sizeof(round));

		return false;
	}
}

methodmap ConvarInfo < StringMap
{
	public ConvarInfo()
	{
		return view_as<ConvarInfo>(new StringMap());
	}

	public void LoadSection(KeyValues kv)
	{
		if (kv.JumpToKey("cvars", false))
		{
			if (kv.GotoFirstSubKey(false))
			{
				do
				{
					char sName[128];
					char sValue[256];

					kv.GetSectionName(sName, sizeof(sName));
					kv.GetString(NULL_STRING, sValue, sizeof(sValue), "");

					// Set value to StringMap and convar
					this.SetString(sName, sValue);

					ConVar convar = FindConVar(sName);
					if (convar)
						convar.SetString(sValue);
				}
				while (kv.GotoNextKey(false));
				kv.GoBack();
			}
			kv.GoBack();
		}
	}

	public ConVar Create(const char[] sName, const char[] sValue, const char[] sDesp, int iFlags=0, bool bMin=false, float flMin=0.0, bool bMax=false, float flMax=0.0)
	{
		ConVar convar = CreateConVar(sName, sValue, sDesp, iFlags, bMin, flMin, bMax, flMax);
		this.SetString(sName, sValue);
		convar.AddChangeHook(Config_ConvarChanged);
		return convar;
	}

	public void Changed(ConVar convar, const char[] sValue)
	{
		char sName[128];
		convar.GetName(sName, sizeof(sName));
		this.SetString(sName, sValue);
	}

	public int LookupInt(const char[] sName)
	{
		char sValue[128];
		this.GetString(sName, sValue, sizeof(sValue));
		return StringToInt(sValue);
	}

	public float LookupFloat(const char[] sName)
	{
		char sValue[128];
		this.GetString(sName, sValue, sizeof(sValue));
		return StringToFloat(sValue);
	}

	public bool LookupBool(const char[] sName)
	{
		char sValue[128];
		this.GetString(sName, sValue, sizeof(sValue));
		return !!StringToInt(sValue);
	}

	public bool LookupIntArray(const char[] sName, int[] iArray, int iLength)
	{
		char sValue[128];
		this.GetString(sName, sValue, sizeof(sValue));

		char[][] sArray = new char[iLength][12];
		if (ExplodeString(sValue, " ", sArray, iLength, 12) != iLength)
			return false;

		for (int i = 0; i < iLength; i++)
			iArray[i] = StringToInt(sArray[i]);

		return true;
	}
}

WeaponList g_WeaponList;
RoundList g_RoundList;
ConvarInfo g_ConvarInfo;

void Config_Init()
{
	g_WeaponList = new WeaponList();
	g_RoundList = new RoundList();
	g_ConvarInfo = new ConvarInfo();
}

void Config_Refresh()
{
	g_WeaponList.Clear();
	g_RoundList.Clear();

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

void Config_ConvarChanged(ConVar convar, const char[] sOldValue, const char[] sNewValue)
{
	g_ConvarInfo.Changed(convar, sNewValue);
}