static bool g_bUsedVest[MAXPLAYERS];

public void KevlarVests_OnPlayerSpawn(BonusRound round, int iClient)
{
	g_bUsedVest[iClient] = false;
}

public Action KevlarVests_OnTakeDamage(BonusRound round, int iVictim, int &iAttacker, int &iInflictor, float &flDamage, int &iDamageType, int &iWeapon, int iDamageCustom)
{
	if (IsSurvivor(iVictim) && iVictim != iAttacker)
	{
		if (!g_bUsedVest[iVictim] && flDamage >= GetEntProp(iVictim, Prop_Send, "m_iHealth"))
		{
			if (TF2_IsPlayerInCondition(iVictim, TFCond_Dazed))
				TF2_RemoveCondition(iVictim, TFCond_Dazed);

			if (round.data)
			{
				char sound[64], sMessage[64];
				round.data.GetString("sound", sound, sizeof(sound));
				if (sound[0] && PrecacheSound(sound))
					EmitSoundToAll(sound, iVictim);

				round.data.GetString("message", sMessage, sizeof(sMessage));
				if (sMessage[0])
					CPrintToChat(iVictim, "%t", sMessage);

				TF2_AddCondition(iVictim, TFCond_SpeedBuffAlly, round.data.GetFloat("boost time"));
			}

			g_bUsedVest[iVictim] = true;

			flDamage = 0.0;
			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}