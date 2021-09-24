static GlobalForward H_OnReplaySaved;
static GlobalForward H_OnReplayDiscarded;
static GlobalForward H_OnTimerEnd_Post;

// =====[ NATIVES ]=====

void CreateNatives()
{
	CreateNative("GOKZ_RP_GetPlaybackInfo", Native_RP_GetPlaybackInfo);
	CreateNative("GOKZ_RP_LoadJumpReplay", Native_RP_LoadJumpReplay);
}

public int Native_RP_GetPlaybackInfo(Handle plugin, int numParams)
{
	HUDInfo info;
	GetPlaybackState(GetNativeCell(1), info);
	SetNativeArray(2, info, sizeof(HUDInfo));
	return 1;
}

public int Native_RP_LoadJumpReplay(Handle plugin, int numParams)
{
	int botClient = LoadJumpReplayBot(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3), GetNativeCell(4), GetNativeCell(5), GetNativeCell(6));
	return botClient;
}

// =====[ FORWARDS ]=====

void CreateGlobalForwards()
{
	H_OnReplaySaved = new GlobalForward("GOKZ_RP_OnReplaySaved", ET_Ignore, Param_Cell, Param_Cell, Param_String);
	H_OnReplayDiscarded = new GlobalForward("GOKZ_RP_OnReplayDiscarded", ET_Ignore, Param_Cell);
	H_OnTimerEnd_Post = new GlobalForward("GOKZ_RP_OnTimerEnd_Post", ET_Ignore, Param_Cell, Param_String, Param_Cell, Param_Float, Param_Cell);
}

void Call_OnReplaySaved(int client, int replayType, const char[] filePath)
{
	Call_StartForward(H_OnReplaySaved);
	Call_PushCell(client);
	Call_PushCell(replayType);
	Call_PushString(filePath);
	Call_Finish();
}

void Call_OnReplayDiscarded(int client)
{
	Call_StartForward(H_OnReplayDiscarded);
	Call_PushCell(client);
	Call_Finish();
}

void Call_OnTimerEnd_Post(int client, const char[] filePath, int course, float time, int teleportsUsed)
{
	Call_StartForward(H_OnTimerEnd_Post);
	Call_PushCell(client);
	Call_PushString(filePath);
	Call_PushCell(course);
	Call_PushFloat(time);
	Call_PushCell(teleportsUsed);
	Call_Finish();
} 
