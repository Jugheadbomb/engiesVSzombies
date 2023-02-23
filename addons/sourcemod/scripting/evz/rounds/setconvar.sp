#pragma semicolon 1
#pragma newdecls required

static StringMap g_hOldConVarValues;
static ConVar sv_cheats;
static ConVar sv_tags;

public void SetConVar_Create(BonusRound round)
{
	g_hOldConVarValues = new StringMap();
	sv_cheats = FindConVar("sv_cheats");
	sv_tags = FindConVar("sv_tags");
}

public bool SetConVar_OnStart(BonusRound round)
{
	if (!round.data)
		return false;

	char sName[256];
	round.data.GetString("convar", sName, sizeof(sName));

	ConVar convar = FindConVar(sName);
	if (!convar)
		return false;

	char sValue[512], sOldValue[512];
	round.data.GetString("value", sValue, sizeof(sValue));
	convar.GetString(sOldValue, sizeof(sOldValue));

	// Don't start effect if the convar value is already set to the desired value
	if (StrEqual(sOldValue, sValue))
		return false;

	g_hOldConVarValues.SetString(sName, sOldValue);
	if (round.data.GetNum("silent"))
	{
		sv_tags.Flags &= ~FCVAR_NOTIFY;

		convar.Flags &= ~FCVAR_NOTIFY;
		convar.SetString(sValue, true);
		convar.Flags |= FCVAR_NOTIFY;

		sv_tags.Flags |= FCVAR_NOTIFY;
	}
	else
		convar.SetString(sValue, true);

	convar.AddChangeHook(OnConVarChanged);

	if (round.data.GetNum("replicate_cheats"))
	{
		for (int iClient = 1; iClient <= MaxClients; iClient++)
		{
			if (IsClientInGame(iClient))
			{
				if (IsFakeClient(iClient))
					SetFakeClientConVar(iClient, "sv_cheats", "0");
				else
					sv_cheats.ReplicateToClient(iClient, "0");
			}
		}
	}

	return true;
}

public void SetConVar_OnEnd(BonusRound round)
{
	char sName[256], sValue[512];
	round.data.GetString("convar", sName, sizeof(sName));
	g_hOldConVarValues.GetString(sName, sValue, sizeof(sValue));

	ConVar convar = FindConVar(sName);

	convar.RemoveChangeHook(OnConVarChanged);

	if (round.data.GetNum("silent"))
	{
		sv_tags.Flags &= ~FCVAR_NOTIFY;

		convar.Flags &= ~FCVAR_NOTIFY;
		convar.SetString(sValue, true);
		convar.Flags |= FCVAR_NOTIFY;

		sv_tags.Flags |= FCVAR_NOTIFY;
	}
	else
		convar.SetString(sValue, true);

	g_hOldConVarValues.Remove(sName);

	if (round.data.GetNum("replicate_cheats"))
	{
		for (int iClient = 1; iClient <= MaxClients; iClient++)
		{
			if (IsClientInGame(iClient))
			{
				if (IsFakeClient(iClient))
					SetFakeClientConVar(iClient, "sv_cheats", "0");
				else
					sv_cheats.ReplicateToClient(iClient, "0");
			}
		}
	}
}

static void OnConVarChanged(ConVar convar, const char[] sOldValue, const char[] sNewValue)
{
	char sName[256];
	convar.GetName(sName, sizeof(sName));

	// Restore the old value
	convar.RemoveChangeHook(OnConVarChanged);
	convar.SetString(sOldValue, true);
	convar.AddChangeHook(OnConVarChanged);

	// Update our stored value
	g_hOldConVarValues.SetString(sName, sNewValue);
}