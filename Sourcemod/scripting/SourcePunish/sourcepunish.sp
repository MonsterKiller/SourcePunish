#pragma semicolon 1

#include <sourcepunish>
#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
//#include <adminmenu>

new Handle:g_hRegPunishPlugins;
new Handle:g_hRegPunishTypes;
new Handle:g_hRegPunishCallbacks;

new Handle:g_hKV;
new Handle:g_hSQL = INVALID_HANDLE;

new g_iServerID;
new g_iModID;
new bool:g_bPunishAllServers;
new bool:g_bPunishAllMods;

public Plugin:myinfo = 
{
    name = "SourcePunish -> Core",
    author = "Monster Killer",
    description = "Punishment tool",
    version = SP_PLUGIN_VERSION,
    url = SP_PLUGIN_URL
};

public OnPluginStart()
{
    LoadTranslations("sourcepunish.phrases");
    CreateConVar("sourcepunish_version", SP_PLUGIN_VERSION, "Current version of SourcePunish", FCVAR_PLUGIN|FCVAR_REPLICATED|FCVAR_SPONLY|FCVAR_NOTIFY);

    SP_LoadConfig();
    SP_LoadDB();
    
    g_hRegPunishPlugins = CreateArray();
    g_hRegPunishTypes = CreateArray(SP_MAXLEN_TYPE);
    g_hRegPunishCallbacks = CreateArray();
    
    new Handle:loaded = CreateGlobalForward("SP_Loaded", ET_Ignore);
    Call_StartForward(loaded);
    Call_Finish();
    CloseHandle(loaded);
    
    //RegAdminCmd("sm_sp", Command_SP, ADMFLAG_KICK, "sp");
}

public OnPluginEnd()
{
    ClearArray(g_hRegPunishPlugins);
    ClearArray(g_hRegPunishTypes);
    ClearArray(g_hRegPunishCallbacks);
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    CreateNative("SP_TimeToString", N_SP_TimeToString);
    CreateNative("SP_RegPunishForward", N_SP_RegPunishForward);
    CreateNative("SP_DeRegPunishForward", N_SP_DeRegPunishForward);
    //CreateNative("SP_SQL_AddPunish", N_SP_SQL_AddPunish);
    return APLRes_Success;
}

SP_LoadConfig()
{
    new String:KVFile[128];
    BuildPath(Path_SM, KVFile, sizeof(KVFile), "configs/sourcepunish.cfg");
    if(!FileExists(KVFile))
        SetFailState("SourcePunish - configs/sourcepunish.cfg not found!");
    g_hKV = CreateKeyValues("SourcePunish");
    FileToKeyValues(g_hKV, KVFile);
    
    
/*    new g_iServerID;
    new g_iModID;
    new bool:g_bPunishAllServers;
    new bool:g_bPunishAllMods;*/
}

SP_LoadDB()
{
    if(!SQL_CheckConfig("sourcepunish"))
        SetFailState("SourcePunish - Could not find database conf \"sourcepunish\"");
    else
        SQL_TConnect(SQLConnect, "sourcepunish");
}

public SQLConnect(Handle:owner, Handle:hndl, const String:error[], any:data)
{
    if (hndl == INVALID_HANDLE)
        SetFailState("SourcePunish - database connection error: %s", error);
    g_hSQL = hndl;
}

public N_SP_TimeToString(Handle:plugin, numparams)
{
    new iTime = GetNativeCell(1);
    new maxlen = GetNativeCell(3);
    decl String:TimeString[maxlen];

    if (iTime == 0)
    {
        Format(TimeString, maxlen, "%t", "SP Time Perm");
        return;
    }
    new iYears = iTime / 31556900;
    iTime -= iYears * 31556900;
    new iMonths = iTime / 2629740;
    iTime -= iMonths * 2629740;
    new iWeeks = iTime / 604800;
    iTime -= iWeeks * 604800;
    new iDays = iTime / 86400;
    iTime -= iDays * 86400;
    new iHours = iTime / 3600;
    iTime -= iHours * 3600;
    new iMinutes = iTime / 60;
    iTime -= iMinutes * 60;
    if (iYears > 0)
        Format(TimeString, maxlen, "%d years ", iWeeks);
    if (iMonths > 0)
        Format(TimeString, maxlen, "%s%d months ", TimeString, iWeeks);
    if (iWeeks > 0)
        Format(TimeString, maxlen, "%s%d weeks ", TimeString, iWeeks);
    if (iDays > 0)
        Format(TimeString, maxlen, "%s%d days ", TimeString, iDays);
    if (iHours > 0)
        Format(TimeString, maxlen, "%s%d hours ", TimeString, iHours);
    if (iMinutes > 0)
        Format(TimeString, maxlen, "%s%d minutes ", TimeString, iMinutes);
    if (iTime > 0)
        Format(TimeString, maxlen, "%s%d seconds ", TimeString, iTime);
    TimeString[strlen(TimeString)-1] = '\0';
    SetNativeString(2, TimeString, maxlen);
}

public N_SP_RegPunishForward(Handle:plugin, numParams) {
    decl String:Type[SP_MAXLEN_TYPE];
    GetNativeString(1, Type, sizeof(Type));
    PushArrayCell(g_hRegPunishPlugins, plugin);
    PushArrayString(g_hRegPunishTypes, Type);
    PushArrayCell(g_hRegPunishCallbacks, GetNativeCell(2));
}

public N_SP_DeRegPunishForward(Handle:plugin, numParams) {
    decl String:Type[SP_MAXLEN_TYPE], String:ArrayString[SP_MAXLEN_TYPE];
    GetNativeString(1, Type, sizeof(Type));
    
    for(new i = 0; i<GetArraySize(g_hRegPunishTypes);i++)
    {
        GetArrayString(g_hRegPunishTypes, i, ArrayString, sizeof(ArrayString));
        if(StrEqual(ArrayString, Type) && plugin == GetArrayCell(g_hRegPunishPlugins, i))
        {
            RemoveFromArray(g_hRegPunishPlugins, i);
            RemoveFromArray(g_hRegPunishTypes, i);
            RemoveFromArray(g_hRegPunishCallbacks, i);
        }
    }
}

public OnClientAuthorized(client, const String:auth[])
{
    decl String:query[512], String:safeauth[40];
    SQL_EscapeString(g_hSQL, auth, safeauth, sizeof(safeauth));
    Format(query,sizeof(query),"SELECT Punish_Type, Punish_Time, Punish_Length, Punish_Auth_Type, Punish_Reason FROM sp_punish WHERE ((Punish_Time + Punish_Length) > %d OR Punish_Length = 0) AND UnPunish = 0 AND (Punish_Player_ID = '%s')", GetTime(), safeauth);
    SQL_TQuery(g_hSQL, SQL_ClientAuthFetch, query, GetClientUserId(client));
}

public SQL_ClientAuthFetch(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
    if (hndl == INVALID_HANDLE)
    {
        LogError("Database Error in SQL_ClientAuthFetch: %s", error);
        return;
    }

    new client = GetClientOfUserId(userid);
    if (client == 0)
        return;

    decl String:reason[SP_MAXLEN_REASON], String:type[SP_MAXLEN_TYPE];
    new starttime;
    new length;
    new authtype;
    while (SQL_FetchRow(hndl))
    {
        SQL_FetchString(hndl, 0, type, sizeof(type));
        starttime = SQL_FetchInt(hndl, 1);
        length = SQL_FetchInt(hndl, 2);
        authtype = SQL_FetchInt(hndl, 3);
        SQL_FetchString(hndl, 4, reason, sizeof(reason));
        
        decl String:ArrayString[SP_MAXLEN_TYPE];
        for(new i = 0; i<GetArraySize(g_hRegPunishTypes);i++)
        {
            GetArrayString(g_hRegPunishTypes, i, ArrayString, sizeof(ArrayString));
            if(StrEqual(ArrayString, type))
            {
                new Handle:f = CreateForward(ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_String);
                AddToForward(f, GetArrayCell(g_hRegPunishPlugins, i), Function:GetArrayCell(g_hRegPunishCallbacks, i));
                Call_StartForward(f);
                Call_PushCell(userid);
                Call_PushCell(starttime);
                Call_PushCell(length);
                Call_PushCell(authtype);
                Call_PushString(reason);
                Call_Finish();
                CloseHandle(f);
            }
        }
    }
}
