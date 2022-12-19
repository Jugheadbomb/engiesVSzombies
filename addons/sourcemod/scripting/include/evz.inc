#if defined _engiesvszombies_included
	#endinput
#endif
#define _engiesvszombies_included

enum BonusRound
{
	BonusRound_None,

	BonusRound_LowGravity,
	BonusRound_CuriousFeeling,
	BonusRound_NoDispensers,
	BonusRound_EarlyOutbreak,
	BonusRound_MurderousJoy,
	BonusRound_KevlarVests,
	BonusRound_DoubleDilemma,
	BonusRound_HighGravity,
	BonusRound_MeleeBattle,
	BonusRound_RandomFits,
	BonusRound_HotPotato,
	BonusRound_NoUpgrades,
	BonusRound_TeamSwap,
	BonusRound_CompetitiveRules,

	BonusRound_Count
};

/**
 * Gets current team survivor is
 * 
 * @return	TFTeam of survivor team
 */
native TFTeam EVZ_GetSurvivorTeam();

/**
 * Gets current zombie team is
 * 
 * @return	TFTeam of zombie team
 */
native TFTeam EVZ_GetZombieTeam();

/**
 * Gets current bonus round
 * 
 * @return	BonusRound value, or BonusRound_None if no bonus round active
 */
native BonusRound EVZ_GetBonusRound();

/**
 * Forward called when zombies are being released
 * 
 * @noreturn
 */
forward void EVZ_OnZombiesRelease();

/**
 * Forward called when zombies are being boosted
 * 
 * @noreturn
 */
forward void EVZ_OnZombiesBoost();

/**
 * Forward called when a last survivor is triggered
 *
 * @param	iClient		Client whose the last survivor
 * @noreturn
 */
forward void EVZ_OnLastSurvivor(int iClient);

public SharedPlugin __pl_engiesvszombies =
{
	name = "engiesvszombies",
	file = "engiesvszombies.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

public void __pl_engiesvszombies_SetNTVOptional()
{
	MarkNativeAsOptional("EVZ_GetSurvivorTeam");
	MarkNativeAsOptional("EVZ_GetZombieTeam");
	MarkNativeAsOptional("EVZ_GetBonusRound");
}