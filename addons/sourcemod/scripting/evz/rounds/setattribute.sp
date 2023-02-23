public bool SetAttribute_OnStart(BonusRound round)
{
	if (!round.data)
		return false;

	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
			ApplyAttributes(round, i);

	return true;
}

public void SetAttribute_OnEnd(BonusRound round)
{
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
			ApplyAttributes(round, i, true);
}

public void SetAttribute_OnPlayerSpawn(BonusRound round, int iClient)
{
	ApplyAttributes(round, iClient);
}

static void ApplyAttributes(BonusRound round, int iClient, bool bRemove = false)
{
	KeyValues kv = round.data;

	bool bApplyToWeapons = kv.GetNum("weapons") != 0;
	if (kv.JumpToKey("attributes", false))
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				char sAttrib[64];
				if (kv.GetSectionName(sAttrib, sizeof(sAttrib)))
				{
					float flValue = kv.GetFloat(NULL_STRING);

					if (bApplyToWeapons)
					{
						for (int i = 0; i < GetEntPropArraySize(iClient, Prop_Send, "m_hMyWeapons"); i++)
						{
							int myWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", i);
							if (myWeapon != -1)
							{
								if (!bRemove)
									TF2Attrib_SetByName(myWeapon, sAttrib, flValue);
								else
									TF2Attrib_RemoveByName(myWeapon, sAttrib);
							}
						}
					}
					else
					{
						if (!bRemove)
							TF2Attrib_SetByName(iClient, sAttrib, flValue);
						else
							TF2Attrib_RemoveByName(iClient, sAttrib);
					}
				}
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
		}
		kv.GoBack();
	}
}