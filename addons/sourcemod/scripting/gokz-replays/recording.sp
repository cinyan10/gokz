/*
	Bot replay recording logic and processes.
	
	Records data every time OnPlayerRunCmdPost is called.
	If the player misses the server record, then the recording will 
	immediately stop and be discarded. Upon beating the server record, 
	a binary file will be written with a 'header' containing 
	information	about the run, followed by the recorded tick data 
	from OnPlayerRunCmdPost.
*/



static bool recording[MAXPLAYERS + 1];
static bool recordingPaused[MAXPLAYERS + 1];
static ArrayList recordedTickData[MAXPLAYERS + 1];



// =====[ PUBLIC ]=====

void StartRecording(int client)
{
	if (IsFakeClient(client))
	{
		return;
	}
	
	DiscardRecording(client);
	recording[client] = true;
	ResumeRecording(client);
}

bool SaveRecording(int client, int course, float time, int teleportsUsed)
{
	if (!recording[client])
	{
		return false;
	}
	
	// Prepare data
	int mode = GOKZ_GetCoreOption(client, Option_Mode);
	int style = GOKZ_GetCoreOption(client, Option_Style);
	int timeType = GOKZ_GetCurrentTimeType(client);
	
	// Setup file path and file
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), 
		"%s/%s/%d_%s_%s_%s.%s", 
		RP_DIRECTORY, gC_CurrentMap, course, gC_ModeNamesShort[mode], gC_StyleNamesShort[style], gC_TimeTypeNames[timeType], RP_FILE_EXTENSION);
	if (FileExists(path))
	{
		DeleteFile(path);
	}
	else
	{  // New replay so add it to replay info cache
		AddToReplayInfoCache(course, mode, style, timeType);
		SortReplayInfoCache();
	}
	
	File file = OpenFile(path, "wb");
	if (file == null)
	{
		LogError("Couldn't create/open replay file to write to: %s", path);
		return false;
	}
	
	// Prepare more data
	char steamID2[24], ip[16], alias[MAX_NAME_LENGTH];
	GetClientAuthId(client, AuthId_Steam2, steamID2, sizeof(steamID2));
	GetClientIP(client, ip, sizeof(ip));
	GetClientName(client, alias, sizeof(alias));
	int tickCount = recordedTickData[client].Length;
	
	// Write header
	file.WriteInt32(RP_MAGIC_NUMBER);
	file.WriteInt8(RP_FORMAT_VERSION);
	file.WriteInt8(strlen(GOKZ_VERSION));
	file.WriteString(GOKZ_VERSION, false);
	file.WriteInt8(strlen(gC_CurrentMap));
	file.WriteString(gC_CurrentMap, false);
	file.WriteInt32(course);
	file.WriteInt32(mode);
	file.WriteInt32(style);
	file.WriteInt32(view_as<int>(time));
	file.WriteInt32(teleportsUsed);
	file.WriteInt32(GetSteamAccountID(client));
	file.WriteInt8(strlen(steamID2));
	file.WriteString(steamID2, false);
	file.WriteInt8(strlen(ip));
	file.WriteString(ip, false);
	file.WriteInt8(strlen(alias));
	file.WriteString(alias, false);
	file.WriteInt32(tickCount);
	
	// Write tick data
	any tickData[RP_TICK_DATA_BLOCKSIZE];
	for (int i = 0; i < tickCount; i++)
	{
		recordedTickData[client].GetArray(i, tickData, RP_TICK_DATA_BLOCKSIZE);
		file.Write(tickData, RP_TICK_DATA_BLOCKSIZE, 4);
	}
	delete file;
	
	// Discard recorded data
	recordedTickData[client].Clear();
	recording[client] = false;
	
	return true;
}

bool SaveRecordingCheater(int client)
{
	if (!recording[client])
	{
		return false;
	}
	
	// Prepare data
	int mode = GOKZ_GetCoreOption(client, Option_Mode);
	int style = GOKZ_GetCoreOption(client, Option_Style);
	
	// Setup file path and file
	int replayNumber = 0;
	char path[PLATFORM_MAX_PATH];
	do
	{
		BuildPath(Path_SM, path, sizeof(path), 
			"%s/%d_%d.%s", 
			RP_DIRECTORY_CHEATERS, GetSteamAccountID(client), replayNumber, RP_FILE_EXTENSION);
		replayNumber++;
	}
	while (FileExists(path));
	
	File file = OpenFile(path, "wb");
	if (file == null)
	{
		LogError("Couldn't create/open replay file to write to: %s", path);
		return false;
	}
	
	// Prepare more data
	char steamID2[24], ip[16], alias[MAX_NAME_LENGTH];
	GetClientAuthId(client, AuthId_Steam2, steamID2, sizeof(steamID2));
	GetClientIP(client, ip, sizeof(ip));
	GetClientName(client, alias, sizeof(alias));
	int tickCount = recordedTickData[client].Length;
	
	// Write header
	file.WriteInt32(RP_MAGIC_NUMBER);
	file.WriteInt8(RP_FORMAT_VERSION);
	file.WriteInt8(strlen(GOKZ_VERSION));
	file.WriteString(GOKZ_VERSION, false);
	file.WriteInt8(strlen(gC_CurrentMap));
	file.WriteString(gC_CurrentMap, false);
	file.WriteInt32(-1);
	file.WriteInt32(mode);
	file.WriteInt32(style);
	file.WriteInt32(view_as<int>(float(-1)));
	file.WriteInt32(-1);
	file.WriteInt32(GetSteamAccountID(client));
	file.WriteInt8(strlen(steamID2));
	file.WriteString(steamID2, false);
	file.WriteInt8(strlen(ip));
	file.WriteString(ip, false);
	file.WriteInt8(strlen(alias));
	file.WriteString(alias, false);
	file.WriteInt32(tickCount);
	
	// Write tick data
	any tickData[RP_TICK_DATA_BLOCKSIZE];
	for (int i = 0; i < tickCount; i++)
	{
		recordedTickData[client].GetArray(i, tickData, RP_TICK_DATA_BLOCKSIZE);
		file.Write(tickData, RP_TICK_DATA_BLOCKSIZE, 4);
	}
	delete file;
	
	// Discard recorded data
	recordedTickData[client].Clear();
	recording[client] = false;
	
	return true;
}

void DiscardRecording(int client)
{
	if (gB_GOKZLocalDB && GOKZ_DB_IsCheater(client))
	{
		SaveRecordingCheater(client);
	}
	else
	{
		recording[client] = false;
		recordedTickData[client].Clear();
	}
}

void PauseRecording(int client)
{
	recordingPaused[client] = true;
}

void ResumeRecording(int client)
{
	recordingPaused[client] = false;
}



// =====[ EVENTS ]=====

void OnMapStart_Recording()
{
	CreateReplaysDirectory(gC_CurrentMap);
}

void OnClientPutInServer_Recording(int client)
{
	if (recordedTickData[client] == INVALID_HANDLE)
	{
		recordedTickData[client] = new ArrayList(RP_TICK_DATA_BLOCKSIZE, 0);
	}
	else
	{  // Just in case it isn't cleared when the client disconnects via GOKZ_OnTimerStopped
		recordedTickData[client].Clear();
	}
}

void OnPlayerRunCmdPost_Recording(int client, int buttons)
{
	if (IsFakeClient(client))
	{
		return;
	}
	
	if (recording[client] && !recordingPaused[client])
	{
		int tick = GetArraySize(recordedTickData[client]);
		recordedTickData[client].Resize(tick + 1);
		
		float origin[3], angles[3];
		Movement_GetOrigin(client, origin);
		Movement_GetEyeAngles(client, angles);
		int flags = GetEntityFlags(client);
		
		recordedTickData[client].Set(tick, origin[0], 0);
		recordedTickData[client].Set(tick, origin[1], 1);
		recordedTickData[client].Set(tick, origin[2], 2);
		recordedTickData[client].Set(tick, angles[0], 3);
		recordedTickData[client].Set(tick, angles[1], 4);
		// Don't bother tracking eye angle roll (angles[2]) - not used
		recordedTickData[client].Set(tick, buttons, 5);
		recordedTickData[client].Set(tick, flags, 6);
	}
}

void GOKZ_OnTimerStart_Recording(int client)
{
	StartRecording(client);
}

void GOKZ_OnTimerEnd_Recording(int client, int course, float time, int teleportsUsed)
{
	if (gB_GOKZLocalDB && GOKZ_DB_IsCheater(client))
	{
		SaveRecordingCheater(client);
	}
	else
	{
		SaveRecording(client, course, time, teleportsUsed);
	}
}

void GOKZ_OnPause_Recording(int client)
{
	PauseRecording(client);
}

void GOKZ_OnResume_Recording(int client)
{
	ResumeRecording(client);
}

void GOKZ_OnTimerStopped_Recording(int client)
{
	DiscardRecording(client);
}

void GOKZ_OnCountedTeleport_Recording(int client)
{
	if (gB_NubRecordMissed[client])
	{
		DiscardRecording(client);
	}
}

void GOKZ_LR_OnRecordMissed_Recording(int client, int recordType)
{
	// If missed PRO record or both records, then can no longer beat a server record
	if (recordType == RecordType_NubAndPro || recordType == RecordType_Pro)
	{
		DiscardRecording(client);
	}
	// If on a NUB run and missed NUB record, then can no longer beat a server record
	// Otherwise wait to see if they teleport before stopping the recording
	if (recordType == RecordType_Nub)
	{
		if (GOKZ_GetTeleportCount(client) > 0)
		{
			DiscardRecording(client);
		}
	}
}



// =====[ PRIVATE ]=====

static void CreateReplaysDirectory(const char[] map)
{
	char path[PLATFORM_MAX_PATH];
	
	// Create parent replay directory
	BuildPath(Path_SM, path, sizeof(path), RP_DIRECTORY);
	if (!DirExists(path))
	{
		CreateDirectory(path, 511);
	}
	
	// Create map's replay directory
	BuildPath(Path_SM, path, sizeof(path), "%s/%s", RP_DIRECTORY, map);
	if (!DirExists(path))
	{
		CreateDirectory(path, 511);
	}
	
	// Create cheaters replay directory
	BuildPath(Path_SM, path, sizeof(path), "%s", RP_DIRECTORY_CHEATERS);
	if (!DirExists(path))
	{
		CreateDirectory(path, 511);
	}
} 