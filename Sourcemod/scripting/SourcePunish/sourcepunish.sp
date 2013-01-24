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
new g_bPunishAllServers;
new g_bPunishAllMods;
new String:g_sDBPrefix[10];

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
    //SP_LoadDB();
    
    g_hRegPunishPlugins = CreateArray();
    g_hRegPunishTypes = CreateArray(SP_MAXLEN_TYPE);
    g_hRegPunishCallbacks = CreateArray();

    //RegAdminCmd("sm_sp", Command_SP, ADMFLAG_KICK, "sp");
}

public OnAllPluginsLoaded()
{
    new Handle:loaded = CreateGlobalForward("SP_Loaded", ET_Ignore);
    Call_StartForward(loaded);
    Call_Finish();
    CloseHandle(loaded);
}

public OnPluginEnd()
{
    ClearArray(g_hRegPunishPlugins);
    ClearArray(g_hRegPunishTypes);
    ClearArray(g_hRegPunishCallbacks);
    CloseHandle(g_hSQL);
    CloseHandle(g_hKV);
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    CreateNative("SP_TimeToString", N_SP_TimeToString);
    CreateNative("SP_RegPunishForward", N_SP_RegPunishForward);
    CreateNative("SP_DeRegPunishForward", N_SP_DeRegPunishForward);
    //CreateNative("SP_DB_AddPunish", N_SP_SQL_AddPunish);
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

    if (!KvJumpToKey(g_hKV, "Settings"))
        SetFailState("SourcePunish - sourcepunish.cfg - settings not found!");

    g_iServerID = KvGetNum(g_hKV, "ServerID", 0);
    g_bPunishAllServers = KvGetNum(g_hKV, "PunishFromAllServers", 1);
    g_bPunishAllMods = KvGetNum(g_hKV, "PunishFromAllMods", 0);
    KvGetString(g_hKV, "DBPrefix", g_sDBPrefix, sizeof(g_sDBPrefix));

    SP_LoadDB();
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
    SP_SQLLoadedConf();
}

SP_SQLLoadedConf()
{
    decl String:sDBPrefixSafe[10], String:query[80], String:serverID[11], String:safeServerID[22];
    SQL_EscapeString(g_hSQL, g_sDBPrefix, sDBPrefixSafe, sizeof(sDBPrefixSafe));
    Format(g_sDBPrefix, sizeof(g_sDBPrefix), sDBPrefixSafe);
    
    IntToString(g_iServerID, serverID, sizeof(serverID));
    SQL_EscapeString(g_hSQL, serverID, safeServerID, sizeof(safeServerID));
    g_iServerID = StringToInt(safeServerID);
    Format(query, sizeof(query), "SELECT Server_Mod FROM %s%s WHERE id = '%s' LIMIT 1", g_sDBPrefix, SP_DB_NAME_SERVER, safeServerID);
    SQL_TQuery(g_hSQL, Query_LoadConf, query, 0);
}

public Query_LoadConf(Handle:owner, Handle:hndl, const String:error[], any:data)
{
    if (hndl == INVALID_HANDLE)
    {
        SetFailState("SourcePunish - Query_LoadConf error: %s", error);
        return;
    }
    SQL_FetchRow(hndl);
    g_iModID = SQL_FetchInt(hndl, 0);
}

public N_SP_TimeToString(Handle:plugin, numparams)
{
    new iTime = GetNativeCell(1);
    new maxlen = GetNativeCell(3);
    decl String:TimeString[maxlen];
    TimeString[0] = '\0';
    if (iTime == 0)
    {
        Format(TimeString, maxlen, "%t", "SP Time Perm");
        SetNativeString(2, TimeString, maxlen);
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
        Format(TimeString, maxlen, "%d %t ", iWeeks, "SP Time Year");
    if (iMonths > 0) 
        Format(TimeString, maxlen, "%s%d %t ", TimeString, iMonths, "SP Time Month");
    if (iWeeks > 0)
        Format(TimeString, maxlen, "%s%d %t ", TimeString, iWeeks, "SP Time Week");
    if (iDays > 0)
        Format(TimeString, maxlen, "%s%d %t ", TimeString, iDays, "SP Time Day");
    if (iHours > 0)
        Format(TimeString, maxlen, "%s%d %t ", TimeString, iHours, "SP Time Hour");
    if (iMinutes > 0)
        Format(TimeString, maxlen, "%s%d %t ", TimeString, iMinutes, "SP Time Min");
    if (iTime > 0)
        Format(TimeString, maxlen, "%s%d %t ", TimeString, iTime, "SP Time Sec");
    PrintToServer("**** TIME: %s",TimeString);
    TimeString[strlen(TimeString)-1] = '\0';
    SetNativeString(2, TimeString, maxlen);
}

public N_SP_RegPunishForward(Handle:plugin, numParams) {
    decl String:Type[SP_MAXLEN_TYPE], String:ArrayString[SP_MAXLEN_TYPE];
    GetNativeString(1, Type, sizeof(Type));

    for(new i = 0; i<GetArraySize(g_hRegPunishPlugins);i++)
    {
        GetArrayString(g_hRegPunishTypes, i, ArrayString, sizeof(ArrayString));
        if(StrEqual(ArrayString, Type) && plugin == GetArrayCell(g_hRegPunishPlugins, i))
        {
            return false;
        }
    }
    PushArrayCell(g_hRegPunishPlugins, plugin);
    PushArrayString(g_hRegPunishTypes, Type);
    PushArrayCell(g_hRegPunishCallbacks, GetNativeCell(2));
    return true;
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
            return true;
        }
    }
    return false;
}

public OnClientAuthorized(client, const String:auth[])
{
    decl String:query[512], String:safeauth[SP_MAXLEN_AUTH*2], String:clientIP[SP_MAXLEN_IP], String:safeclientIP[SP_MAXLEN_IP*2];
    GetClientIP(client, clientIP, sizeof(clientIP));
    SQL_EscapeString(g_hSQL, clientIP, safeclientIP, sizeof(safeclientIP));
    SQL_EscapeString(g_hSQL, auth, safeauth, sizeof(safeauth));
    Format(query, sizeof(query), "SELECT Punish_Type, Punish_Time, Punish_Length, Punish_Auth_Type, Punish_Reason FROM %s%s WHERE ((Punish_Time + (Punish_Length*60)) > %d OR Punish_Length = 0) AND UnPunish = 0 AND (Punish_Player_ID = '%s' OR Punish_Player_IP = '%s') AND IF(Punish_All_Servers=1, IF(Punish_All_Mods=0, Punish_Server_ID IN (SELECT ID FROM sp_servers WHERE Server_Mod = %d), 1), Punish_Server_ID=%d)", g_sDBPrefix, SP_DB_NAME, GetTime(), safeauth, safeclientIP, g_iModID, g_iServerID);
    SQL_TQuery(g_hSQL, Query_ClientAuthFetch, query, GetClientUserId(client));
}

public Query_ClientAuthFetch(Handle:owner, Handle:hndl, const String:error[], any:userid)
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

public N_SP_DB_AddPunish(Handle:plugin, numparams)
{
    decl String:PunishType[SP_MAXLEN_TYPE], String:PunishReason[SP_MAXLEN_REASON];

    new PunishedUserID = GetNativeCell(1);
    new PunisherUserID = GetNativeCell(2);
    new PunishLength = GetNativeCell(3);
    new PunishAuthType = GetNativeCell(4);
    GetNativeString(5, PunishType, sizeof(PunishType));
    GetNativeString(6, PunishReason, sizeof(PunishReason));

    new Punished = GetClientOfUserId(PunishedUserID);
    new Punisher = GetClientOfUserId(PunisherUserID);

    decl String:PunishedName[SP_MAXLEN_NAME], String:PunishedAuth[SP_MAXLEN_AUTH], String:PunishedIP[SP_MAXLEN_IP], String:PunisherName[SP_MAXLEN_NAME], String:PunisherAuth[SP_MAXLEN_AUTH];

    GetClientName(Punished, PunishedName, sizeof(PunishedName));
    GetClientName(Punisher, PunisherName, sizeof(PunisherName));
    GetClientAuthString(Punished, PunishedAuth, sizeof(PunishedAuth));
    GetClientAuthString(Punisher, PunisherAuth, sizeof(PunisherAuth));
    GetClientIP(Punished, PunishedIP, sizeof(PunishedIP));

    decl String:SPunishedName[SP_MAXLEN_NAME*2], String:SPunishedAuth[SP_MAXLEN_AUTH*2], String:SPunishedIP[SP_MAXLEN_IP*2], String:SPunisherName[SP_MAXLEN_NAME*2], String:SPunisherAuth[SP_MAXLEN_AUTH*2], String:SPunishReason[SP_MAXLEN_REASON*2], String:SPunishType[SP_MAXLEN_TYPE*2], String:SPunishLength[20];

    SQL_EscapeString(g_hSQL, PunishedName, SPunishedName, sizeof(SPunishedName));
    SQL_EscapeString(g_hSQL, PunisherName, SPunisherName, sizeof(SPunisherName));
    SQL_EscapeString(g_hSQL, PunishedAuth, SPunishedAuth, sizeof(SPunishedAuth));
    SQL_EscapeString(g_hSQL, PunisherAuth, SPunisherAuth, sizeof(SPunisherAuth));
    SQL_EscapeString(g_hSQL, PunishedIP, SPunishedIP, sizeof(SPunishedIP));
    SQL_EscapeString(g_hSQL, PunishType, SPunishType, sizeof(SPunishType));
    SQL_EscapeString(g_hSQL, PunishReason, SPunishReason, sizeof(SPunishReason));
}
