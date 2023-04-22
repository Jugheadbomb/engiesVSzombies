#define CONFIG_PATH "configs/evz/evz.cfg"

enum FindValue
{
	Value_Index = 0,
	Value_Classname
};

static ArrayList g_aWeapons;
static StringMap g_sConvars;

enum struct Weapon
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
			strcopy(this.sClassname, sizeof(this.sClassname), sBuffer);
		else
			this.iIndex = iIndex;

		if (this.iIndex == -1 && !this.sClassname[0])
			return false;

		this.iIndexPrefab = kv.GetNum("prefab", -1);
		this.iIndexReplace = kv.GetNum("replace", -1);
		this.iKillComboCrit = kv.GetNum("kill_combo_crit");
		this.bBlockSecondary = !!kv.GetNum("block_m2");
		this.bSentry = !!kv.GetNum("sentry");

		kv.GetString("name", this.sName, sizeof(this.sName));
		kv.GetString("desc", this.sDesc, sizeof(this.sDesc));
		kv.GetString("attrib", this.sAttrib, sizeof(this.sAttrib));
		kv.GetString("attrib_onswitch", this.sAttribSwitch, sizeof(this.sAttribSwitch));
		return (this.sName[0] && this.sDesc[0]);
	}
}

methodmap WeaponList
{
	public static ArrayList GetList()
	{
		return g_aWeapons;
	}

	public static void LoadSection(KeyValues kv)
	{
		if (kv.JumpToKey("weapons", false))
		{
			if (kv.GotoFirstSubKey())
			{
				do
				{
					Weapon weapon;
					if (weapon.ReadFromKv(kv))
						g_aWeapons.PushArray(weapon, sizeof(weapon));
				}
				while (kv.GotoNextKey());
				kv.GoBack();
			}
			kv.GoBack();
		}
	}

	public static bool GetByEntity(int iWeapon, Weapon weapon, FindValue findval)
	{
		switch (findval)
		{
			case Value_Index:
			{
				int index = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
				return WeaponList.GetByDefIndex(index, weapon);
			}
			case Value_Classname:
			{
				char sClassname[64];
				GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
				return WeaponList.GetByClassname(sClassname, weapon);
			}
		}

		return false;
	}

	public static bool GetByDefIndex(int index, Weapon weapon)
	{
		int i = g_aWeapons.FindValue(index, Weapon::iIndex);
		if (i != -1)
			return !!g_aWeapons.GetArray(i, weapon);

		return false;
	}

	public static bool GetByClassname(const char[] sClassname, Weapon weapon)
	{
		for (int i = 0; i < g_aWeapons.Length; i++)
		{
			if (!g_aWeapons.GetArray(i, weapon, sizeof(weapon)))
				continue;

			if (StrEqual(weapon.sClassname, sClassname, false))
				return true;
		}

		return false;
	}
}

methodmap ConvarInfo
{
	public static StringMap GetMap()
	{
		return g_sConvars;
	}

	public static void LoadSection(KeyValues kv)
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
					g_sConvars.SetString(sName, sValue);

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

	public static ConVar Create(const char[] sName, const char[] sValue, const char[] sDesp, int iFlags=0, bool bMin=false, float flMin=0.0, bool bMax=false, float flMax=0.0)
	{
		ConVar convar = CreateConVar(sName, sValue, sDesp, iFlags, bMin, flMin, bMax, flMax);
		g_sConvars.SetString(sName, sValue);
		convar.AddChangeHook(Config_ConvarChanged);
		return convar;
	}

	public static void Changed(ConVar convar, const char[] sValue)
	{
		char sName[128];
		convar.GetName(sName, sizeof(sName));
		g_sConvars.SetString(sName, sValue);
	}

	public static int LookupInt(const char[] sName)
	{
		char sValue[128];
		g_sConvars.GetString(sName, sValue, sizeof(sValue));
		return StringToInt(sValue);
	}

	public static float LookupFloat(const char[] sName)
	{
		char sValue[128];
		g_sConvars.GetString(sName, sValue, sizeof(sValue));
		return StringToFloat(sValue);
	}

	public static bool LookupBool(const char[] sName)
	{
		char sValue[128];
		g_sConvars.GetString(sName, sValue, sizeof(sValue));
		return !!StringToInt(sValue);
	}

	public static bool LookupIntArray(const char[] sName, int[] iArray, int iLength)
	{
		char sValue[128];
		g_sConvars.GetString(sName, sValue, sizeof(sValue));

		char[][] sArray = new char[iLength][12];
		if (ExplodeString(sValue, " ", sArray, iLength, 12) != iLength)
			return false;

		for (int i = 0; i < iLength; i++)
			iArray[i] = StringToInt(sArray[i]);

		return true;
	}
}

void Config_Init()
{
	g_aWeapons = new ArrayList(sizeof(Weapon));
	g_sConvars = new StringMap();
}

void Config_Refresh()
{
	g_sConvars.Clear();

	KeyValues kv = Config_LoadFile(CONFIG_PATH);
	if (!kv)
		return;

	WeaponList.LoadSection(kv);
	ConvarInfo.LoadSection(kv);
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

	KeyValues kv = new KeyValues("config");
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
	ConvarInfo.Changed(convar, sNewValue);
}