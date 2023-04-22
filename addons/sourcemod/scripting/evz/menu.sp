static int g_iMenuSelection[TF_MAXPLAYERS];

void Menu_DisplayMain(int iClient)
{
	Menu hMenu = new Menu(Menu_SelectMain);
	hMenu.SetTitle("%T", "#Menu_MainTitle", iClient, PLUGIN_VERSION, PLUGIN_VERSION_REVISION);

	Menu_AddItemTranslation(hMenu, "overview", "#Menu_MainOverview", iClient);
	Menu_AddItemTranslation(hMenu, "team_survivor", "#Menu_MainTeamSurvivor", iClient);
	Menu_AddItemTranslation(hMenu, "team_zombie", "#Menu_MainTeamZombie", iClient);
	Menu_AddItemTranslation(hMenu, "balances", "#Menu_MainBalances", iClient);
	if (ConvarInfo.LookupBool("evz_bonus_rounds_enable"))
		Menu_AddItemTranslation(hMenu, "bonusrounds", "#Menu_MainBonusRounds", iClient);

	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

int Menu_SelectMain(Menu hMenu, MenuAction action, int iClient, int iSlot)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[16];
			hMenu.GetItem(iSlot, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "overview"))
				Menu_DisplayInfo(iClient, "#Menu_MainOverview", "#Menu_Overview");
			else if (StrEqual(sInfo, "team_survivor"))
				Menu_DisplayInfo(iClient, "#Menu_MainTeamSurvivor", "#Menu_TeamSurvivor");
			else if (StrEqual(sInfo, "team_zombie"))
				Menu_DisplayInfo(iClient, "#Menu_MainTeamZombie", "#Menu_TeamZombie");
			else if (StrEqual(sInfo, "balances"))
				Menu_DisplayBalances(iClient);
			else if (StrEqual(sInfo, "bonusrounds"))
				Menu_DisplayBonusRounds(iClient);
		}
		case MenuAction_End: delete hMenu;
	}

	return 0;
}

void Menu_DisplayInfo(int iClient, const char[] sTitle, const char[] sInfo)
{
	char sBuffer[512];
	Menu hMenu = new Menu(Menu_SelectInfo);

	Format(sBuffer, sizeof(sBuffer), "%T", sTitle, iClient);
	StrCat(sBuffer, sizeof(sBuffer), "\n-------------------------------------------");

	Format(sBuffer, sizeof(sBuffer), "%s\n%T", sBuffer, sInfo, iClient);
	StrCat(sBuffer, sizeof(sBuffer), "\n-------------------------------------------");

	hMenu.SetTitle(sBuffer);
	Menu_AddItemTranslation(hMenu, "back", "#Menu_MainBack", iClient);

	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

int Menu_SelectInfo(Menu hMenu, MenuAction action, int iClient, int iSlot)
{
	switch (action)
	{
		case MenuAction_Select: Menu_DisplayMain(iClient);
		case MenuAction_End: delete hMenu;
	}

	return 0;
}

void Menu_DisplayBalances(int iClient, int iSelection = -1)
{
	Menu hMenu = new Menu(Menu_SelectBalances);
	hMenu.SetTitle("%T", "#Menu_MainBalances", iClient);

	char sBuffer[16];
	for (int i = 0; i < WeaponList.GetList().Length; i++)
	{
		Weapon weapon;
		WeaponList.GetList().GetArray(i, weapon, sizeof(weapon));

		Format(sBuffer, sizeof(sBuffer), "%i", i);
		Menu_AddItemTranslation(hMenu, sBuffer, weapon.sName, iClient);
	}

	hMenu.ExitBackButton = true;

	if (iSelection == -1)
		hMenu.Display(iClient, MENU_TIME_FOREVER);
	else
		hMenu.DisplayAt(iClient, iSelection, MENU_TIME_FOREVER);
}

int Menu_SelectBalances(Menu hMenu, MenuAction action, int iClient, int iSlot)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[16];
			hMenu.GetItem(iSlot, sInfo, sizeof(sInfo));

			Weapon weapon;
			WeaponList.GetList().GetArray(StringToInt(sInfo), weapon, sizeof(weapon));
			Menu_DisplayWeapon(iClient, weapon);

			g_iMenuSelection[iClient] = GetMenuSelectionPosition();
		}
		case MenuAction_Cancel:
		{
			if (iSlot == MenuCancel_ExitBack)
				Menu_DisplayMain(iClient);
		}
		case MenuAction_End: delete hMenu;
	}

	return 0;
}

void Menu_DisplayWeapon(int iClient, Weapon weapon)
{
	char sBuffer[512];
	Menu hMenu = new Menu(Menu_SelectWeapon);

	Format(sBuffer, sizeof(sBuffer), "%T", weapon.sName, iClient);
	StrCat(sBuffer, sizeof(sBuffer), "\n-------------------------------------------");

	Format(sBuffer, sizeof(sBuffer), "%s\n%T", sBuffer, weapon.sDesc, iClient);
	StrCat(sBuffer, sizeof(sBuffer), "\n-------------------------------------------");

	ReplaceString(sBuffer, sizeof(sBuffer), "{red}", "");
	ReplaceString(sBuffer, sizeof(sBuffer), "{green}", "");
	ReplaceString(sBuffer, sizeof(sBuffer), "{gray}", "");
	ReplaceString(sBuffer, sizeof(sBuffer), "%", "%%");

	hMenu.SetTitle(sBuffer);
	Menu_AddItemTranslation(hMenu, "back", "#Menu_MainBack", iClient);

	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

int Menu_SelectWeapon(Menu hMenu, MenuAction action, int iClient, int iSlot)
{
	switch (action)
	{
		case MenuAction_Select: Menu_DisplayBalances(iClient, g_iMenuSelection[iClient]);
		case MenuAction_End: delete hMenu;
	}

	return 0;
}

void Menu_DisplayBonusRounds(int iClient, int iSelection = -1)
{
	Menu hMenu = new Menu(Menu_SelectBonusRounds);
	hMenu.SetTitle("%T", "#Menu_MainBonusRounds", iClient);

	char sBuffer[16];
	for (int i = 0; i < RoundList.GetList().Length; i++)
	{
		BonusRound round;
		if (RoundList.GetList().GetArray(i, round) && round.bEnabled)
		{
			Format(sBuffer, sizeof(sBuffer), "%i", i);
			Menu_AddItemTranslation(hMenu, sBuffer, round.sName, iClient, round.sDesc[0] ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
	}

	hMenu.ExitBackButton = true;

	if (iSelection == -1)
		hMenu.Display(iClient, MENU_TIME_FOREVER);
	else
		hMenu.DisplayAt(iClient, iSelection, MENU_TIME_FOREVER);
}

int Menu_SelectBonusRounds(Menu hMenu, MenuAction action, int iClient, int iSlot)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[16];
			hMenu.GetItem(iSlot, sInfo, sizeof(sInfo));

			BonusRound round;
			if (RoundList.GetList().GetArray(StringToInt(sInfo), round))
				Menu_DisplayRound(iClient, round);

			g_iMenuSelection[iClient] = GetMenuSelectionPosition();
		}
		case MenuAction_Cancel:
		{
			if (iSlot == MenuCancel_ExitBack)
				Menu_DisplayMain(iClient);
		}
		case MenuAction_End: delete hMenu;
	}

	return 0;
}

void Menu_DisplayRound(int iClient, BonusRound round)
{
	char sBuffer[512];
	Menu hMenu = new Menu(Menu_SelectRound);

	Format(sBuffer, sizeof(sBuffer), "%T", round.sName, iClient);
	StrCat(sBuffer, sizeof(sBuffer), "\n-------------------------------------------");

	Format(sBuffer, sizeof(sBuffer), "%s\n%T", sBuffer, round.sDesc, iClient);
	StrCat(sBuffer, sizeof(sBuffer), "\n-------------------------------------------");

	hMenu.SetTitle(sBuffer);
	Menu_AddItemTranslation(hMenu, "back", "#Menu_MainBack", iClient);

	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

int Menu_SelectRound(Menu hMenu, MenuAction action, int iClient, int iSlot)
{
	switch (action)
	{
		case MenuAction_Select: Menu_DisplayBonusRounds(iClient, g_iMenuSelection[iClient]);
		case MenuAction_End: delete hMenu;
	}

	return 0;
}

void Menu_AddItemTranslation(Menu hMenu, const char[] sInfo, const char[] sTranslation, int iClient, int iItemDraw = ITEMDRAW_DEFAULT)
{
	char sBuffer[256];
	Format(sBuffer, sizeof(sBuffer), "%T", sTranslation, iClient);
	hMenu.AddItem(sInfo, sBuffer, iItemDraw);
}