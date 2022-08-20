static int g_iMenuSelection[TF_MAXPLAYERS];

void Menu_DisplayMain(int iClient)
{
	Menu hMenu = new Menu(Menu_SelectMain);
	hMenu.SetTitle("%T", "Menu_MainTitle", iClient);

	Menu_AddItemTranslation(hMenu, "overview", "Menu_MainOverview", iClient);
	Menu_AddItemTranslation(hMenu, "team_survivor", "Menu_MainTeamSurvivor", iClient);
	Menu_AddItemTranslation(hMenu, "team_zombie", "Menu_MainTeamZombie", iClient);
	Menu_AddItemTranslation(hMenu, "balances", "Menu_MainBalances", iClient);
	if (g_ConvarInfo.LookupBool("evz_bonus_rounds_enable"))
		Menu_AddItemTranslation(hMenu, "bonusrounds", "Menu_MainBonusRounds", iClient);

	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int Menu_SelectMain(Menu hMenu, MenuAction action, int iClient, int iSlot)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[16];
			hMenu.GetItem(iSlot, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "overview"))
				Menu_DisplayInfo(iClient, "Menu_MainOverview", "Menu_Overview");
			else if (StrEqual(sInfo, "team_survivor"))
				Menu_DisplayInfo(iClient, "Menu_MainTeamSurvivor", "Menu_TeamSurvivor");
			else if (StrEqual(sInfo, "team_zombie"))
				Menu_DisplayInfo(iClient, "Menu_MainTeamZombie", "Menu_TeamZombie");
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
	Menu_AddItemTranslation(hMenu, "back", "Menu_MainBack", iClient);

	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int Menu_SelectInfo(Menu hMenu, MenuAction action, int iClient, int iSlot)
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
	hMenu.SetTitle("%T", "Menu_MainBalances", iClient);

	char sBuffer[16];
	for (int i = 0; i < g_aWeapons.Length; i++)
	{
		WeaponConfig config;
		g_aWeapons.GetArray(i, config, sizeof(config));

		Format(sBuffer, sizeof(sBuffer), "%i", i);
		Menu_AddItemTranslation(hMenu, sBuffer, config.sName, iClient);
	}

	hMenu.ExitBackButton = true;

	if (iSelection == -1)
		hMenu.Display(iClient, MENU_TIME_FOREVER);
	else
		hMenu.DisplayAt(iClient, iSelection, MENU_TIME_FOREVER);
}

public int Menu_SelectBalances(Menu hMenu, MenuAction action, int iClient, int iSlot)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[16];
			hMenu.GetItem(iSlot, sInfo, sizeof(sInfo));

			WeaponConfig config;
			g_aWeapons.GetArray(StringToInt(sInfo), config, sizeof(config));
			Menu_DisplayWeapon(iClient, config);

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

void Menu_DisplayWeapon(int iClient, WeaponConfig config)
{
	char sBuffer[512];
	Menu hMenu = new Menu(Menu_SelectWeapon);

	Format(sBuffer, sizeof(sBuffer), "%T", config.sName, iClient);
	StrCat(sBuffer, sizeof(sBuffer), "\n-------------------------------------------");

	Format(sBuffer, sizeof(sBuffer), "%s\n%T", sBuffer, config.sDesc, iClient);
	StrCat(sBuffer, sizeof(sBuffer), "\n-------------------------------------------");

	ReplaceString(sBuffer, sizeof(sBuffer), "{red}", "");
	ReplaceString(sBuffer, sizeof(sBuffer), "{green}", "");
	ReplaceString(sBuffer, sizeof(sBuffer), "{gray}", "");
	ReplaceString(sBuffer, sizeof(sBuffer), "%", "%%");

	hMenu.SetTitle(sBuffer);
	Menu_AddItemTranslation(hMenu, "back", "Menu_MainBack", iClient);

	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int Menu_SelectWeapon(Menu hMenu, MenuAction action, int iClient, int iSlot)
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
	hMenu.SetTitle("%T", "Menu_MainBonusRounds", iClient);

	char sCurrent[128];
	Format(sCurrent, sizeof(sCurrent), "%T", "Menu_CurrentRound", iClient);

	RoundConfig config;
	if (RoundConfig_GetCurrent(config))
		Format(sCurrent, sizeof(sCurrent), "%s: %T", sCurrent, config.sName, iClient);
	else
		Format(sCurrent, sizeof(sCurrent), "%s: %T", sCurrent, "Menu_None", iClient);

	hMenu.AddItem("current", sCurrent, ITEMDRAW_DISABLED);

	char sBuffer[16];
	for (int i = 0; i < g_aRounds.Length; i++)
	{
		g_aRounds.GetArray(i, config, sizeof(config));

		Format(sBuffer, sizeof(sBuffer), "%i", i);
		Menu_AddItemTranslation(hMenu, sBuffer, config.sName, iClient);
	}

	hMenu.ExitBackButton = true;

	if (iSelection == -1)
		hMenu.Display(iClient, MENU_TIME_FOREVER);
	else
		hMenu.DisplayAt(iClient, iSelection, MENU_TIME_FOREVER);
}

public int Menu_SelectBonusRounds(Menu hMenu, MenuAction action, int iClient, int iSlot)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[16];
			hMenu.GetItem(iSlot, sInfo, sizeof(sInfo));

			RoundConfig config;
			g_aRounds.GetArray(StringToInt(sInfo), config, sizeof(config));
			Menu_DisplayRound(iClient, config);

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

void Menu_DisplayRound(int iClient, RoundConfig config)
{
	char sBuffer[512];
	Menu hMenu = new Menu(Menu_SelectRound);

	Format(sBuffer, sizeof(sBuffer), "%T", config.sName, iClient);
	StrCat(sBuffer, sizeof(sBuffer), "\n-------------------------------------------");

	Format(sBuffer, sizeof(sBuffer), "%s\n%T", sBuffer, config.sDesc, iClient);
	StrCat(sBuffer, sizeof(sBuffer), "\n-------------------------------------------");

	hMenu.SetTitle(sBuffer);
	Menu_AddItemTranslation(hMenu, "back", "Menu_MainBack", iClient);

	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int Menu_SelectRound(Menu hMenu, MenuAction action, int iClient, int iSlot)
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