/*	
	Uses HUD text to show the race countdown and a start message.
*/



static Handle racingHudSynchronizer;
static float countdownStartTime[MAXPLAYERS + 1];



// =====[ EVENTS ]=====

void OnPluginStart_RacingText()
{
	racingHudSynchronizer = CreateHudSynchronizer();
}

void OnPlayerRunCmdPost_RacingText(int client, int cmdnum)
{
	if (gB_GOKZRacing && cmdnum % 6 == 3)
	{
		UpdateRacingText(client);
	}
}

void OnRaceInfoChanged_RacingText(int raceID, RaceInfo prop, int newValue)
{
	if (prop != RaceInfo_Status)
	{
		return;
	}
	
	if (newValue == RaceStatus_Countdown)
	{
		for (int client = 1; client <= MaxClients; client++)
		{
			if (GOKZ_RC_GetRaceID(client) == raceID)
			{
				countdownStartTime[client] = GetGameTime();
			}
		}
	}
	else if (newValue == RaceStatus_Aborting)
	{
		for (int client = 1; client <= MaxClients; client++)
		{
			if (GOKZ_RC_GetRaceID(client) == raceID)
			{
				ClearRacingText(client);
			}
		}
	}
}



// =====[ PRIVATE ]=====

static void UpdateRacingText(int client)
{
	KZPlayer player = KZPlayer(client);
	
	if (player.fake)
	{
		return;
	}
	
	if (player.alive)
	{
		RacingTextShow(player, player);
	}
	else
	{
		KZPlayer targetPlayer = KZPlayer(player.observerTarget);
		if (targetPlayer.id != -1 && !targetPlayer.fake)
		{
			RacingTextShow(player, targetPlayer);
		}
	}
}

static void ClearRacingText(int client)
{
	ClearSyncHud(client, racingHudSynchronizer);
}

static void RacingTextShow(KZPlayer player, KZPlayer targetPlayer)
{
	if (GOKZ_RC_GetStatus(targetPlayer.id) != RacerStatus_Racing)
	{
		return;
	}
	
	int raceStatus = GOKZ_RC_GetRaceInfo(GOKZ_RC_GetRaceID(targetPlayer.id), RaceInfo_Status);
	if (raceStatus == RaceStatus_Countdown)
	{
		ShowCountdownText(player, targetPlayer);
	}
	else if (raceStatus == RaceStatus_Started)
	{
		ShowStartedText(player, targetPlayer);
	}
}

static void ShowCountdownText(KZPlayer player, KZPlayer targetPlayer)
{
	float timeToStart = (countdownStartTime[targetPlayer.id] + RC_COUNTDOWN_TIME) - GetGameTime();
	int colour[4];
	GetCountdownColour(timeToStart, colour);
	
	SetHudTextParams(-1.0, 0.3, 1.0, colour[0], colour[1], colour[2], colour[3], 0, 1.0, 0.0, 0.0);
	ShowSyncHudText(player.id, racingHudSynchronizer, "%t\n\n%d", "Get Ready", IntMax(RoundToCeil(timeToStart), 1));
}

static float[] GetCountdownColour(float timeToStart, int buffer[4])
{
	// From red to green
	if (timeToStart >= RC_COUNTDOWN_TIME)
	{
		buffer[0] = 255;
		buffer[1] = 0;
	}
	else if (timeToStart > RC_COUNTDOWN_TIME / 2.0)
	{
		buffer[0] = 255;
		buffer[1] = RoundFloat(-510.0 / RC_COUNTDOWN_TIME * timeToStart + 510.0);
	}
	else if (timeToStart > 0.0)
	{
		buffer[0] = RoundFloat(510.0 / RC_COUNTDOWN_TIME * timeToStart);
		buffer[1] = 255;
	}
	else
	{
		buffer[0] = 0;
		buffer[1] = 255;
	}
	
	buffer[2] = 0;
	buffer[3] = 255;
}

static void ShowStartedText(KZPlayer player, KZPlayer targetPlayer)
{
	if (targetPlayer.timerRunning)
	{
		return;
	}
	
	SetHudTextParams(-1.0, 0.3, 1.0, 0, 255, 0, 255, 0, 1.0, 0.0, 0.0);
	ShowSyncHudText(player.id, racingHudSynchronizer, "%t", "Go!");
} 