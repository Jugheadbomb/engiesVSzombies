methodmap ConvarInfo < StringMap
{
	public ConvarInfo()
	{
		return view_as<ConvarInfo>(new StringMap());
	}

	public ConVar Create(const char[] sName, const char[] sValue, const char[] sDesp, int iFlags=0, bool bMin=false, float flMin=0.0, bool bMax=false, float flMax=0.0)
	{
		ConVar convar = CreateConVar(sName, sValue, sDesp, iFlags, bMin, flMin, bMax, flMax);
		this.SetString(sName, sValue);
		convar.AddChangeHook(ConvarInfo_Changed);
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

ConvarInfo g_ConvarInfo;

void ConVar_Init()
{
	g_ConvarInfo = new ConvarInfo();
}

void ConvarInfo_Changed(ConVar convar, const char[] sOldValue, const char[] sNewValue)
{
	g_ConvarInfo.Changed(convar, sNewValue);
}