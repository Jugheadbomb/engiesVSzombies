#if defined _engiesvszombies_included
	#endinput
#endif
#define _engiesvszombies_included

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
}