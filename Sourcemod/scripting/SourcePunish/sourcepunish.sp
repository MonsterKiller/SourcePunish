#pragma semicolon 1

#include <sourcepunish>
#include <sourcemod>
#include <sdktools>

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
    
    g_hRegPunishPlugins = CreateArray();
    g_hRegPunishTypes = CreateArray(SP_MAXLEN_TYPE);
    g_hRegPunishCallbacks = CreateArray();

    //RegAdminCmd("sm_sp", Command_SP, ADMFLAG_KICK, "sp");
}

public OnAllPluginsLoaded()
{
    new Handle:hLoaded = CreateGlobalForward("SP_Loaded", ET_Ignore);
    Call_StartForward(hLoaded);
    Call_Finish();
    CloseHandle(hLoaded);
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
    CreateNative("SP_DB_AddPunish", N_SP_DB_AddPunish);
    CreateNative("SP_DB_UnPunish", N_SP_DB_AddPunish);
    RegPluginLibrary("sourcepunish");
    return APLRes_Success;
}

SP_LoadConfig()
{
    new String:sKVFile[128];
    BuildPath(Path_SM, sKVFile, sizeof(sKVFile), "configs/sourcepunish.cfg");
    if(!FileExists(sKVFile))
        SetFailState("SourcePunish - configs/sourcepunish.cfg not found!");
    g_hKV = CreateKeyValues("SourcePunish");
    FileToKeyValues(g_hKV, sKVFile);

    if (!KvJumpToKey(g_hKV, "Settings"))
        SetFailState("SourcePunish - sourcepunish.cfg - settings not found!");

    g_iServerID = KvGetNum(g_hKV, "ServerID", 0);
    if(g_iServerID > 1)
        SetFailState("SourcePunish - sourcepunish.cfg - invalud server id!");
    g_bPunishAllServers = KvGetNum(g_hKV, "PunishFromAllServers", 1);
    if(g_bPunishAllServers != 1) g_bPunishAllServers = 0;
    g_bPunishAllMods = KvGetNum(g_hKV, "PunishFromAllMods", 0);
    if(g_bPunishAllMods != 0) g_bPunishAllMods = 1;
    KvGetString(g_hKV, "DBPrefix", g_sDBPrefix, sizeof(g_sDBPrefix));
    
    // We should also load a list of punishment times & reasons to create a menu hadle to use with a native

    SP_LoadDB();
}

SP_LoadDB()
{
    if(!SQL_CheckConfig("sourcepunish"))
        SetFailState("SourcePunish - Could not find database confing \"sourcepunish\"");
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
    decl String:sDBPrefixSafe[10], String:sQuery[80], String:sServerID[11], String:sSafeServerID[22];
    SQL_EscapeString(g_hSQL, g_sDBPrefix, sDBPrefixSafe, sizeof(sDBPrefixSafe));
    Format(g_sDBPrefix, sizeof(g_sDBPrefix), sDBPrefixSafe);
    
    IntToString(g_iServerID, sServerID, sizeof(sServerID));
    SQL_EscapeString(g_hSQL, sServerID, sSafeServerID, sizeof(sSafeServerID));
    g_iServerID = StringToInt(sSafeServerID);
    Format(sQuery, sizeof(sQuery), "SELECT Server_Mod FROM %s%s WHERE id = '%s' LIMIT 1", g_sDBPrefix, SP_DB_NAME_SERVER, sSafeServerID);
    SQL_TQuery(g_hSQL, Query_LoadConf, sQuery, 0);
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
    new iMaxlen = GetNativeCell(3);
    decl String:sTimeString[iMaxlen];
    sTimeString[0] = '\0';
    if (iTime == 0)
    {
        Format(sTimeString, iMaxlen, "%t", "SP Time Perm");
        SetNativeString(2, sTimeString, iMaxlen);
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
        Format(sTimeString, iMaxlen, "%d %t ", iWeeks, "SP Time Year");
    if (iMonths > 0) 
        Format(sTimeString, iMaxlen, "%s%d %t ", sTimeString, iMonths, "SP Time Month");
    if (iWeeks > 0)
        Format(sTimeString, iMaxlen, "%s%d %t ", sTimeString, iWeeks, "SP Time Week");
    if (iDays > 0)
        Format(sTimeString, iMaxlen, "%s%d %t ", sTimeString, iDays, "SP Time Day");
    if (iHours > 0)
        Format(sTimeString, iMaxlen, "%s%d %t ", sTimeString, iHours, "SP Time Hour");
    if (iMinutes > 0)
        Format(sTimeString, iMaxlen, "%s%d %t ", sTimeString, iMinutes, "SP Time Min");
    if (iTime > 0)
        Format(sTimeString, iMaxlen, "%s%d %t ", sTimeString, iTime, "SP Time Sec");
    sTimeString[strlen(sTimeString)-1] = '\0';
    SetNativeString(2, sTimeString, iMaxlen);
}

public N_SP_MenuTimes(Handle:plugin, numparams)
{
    // return a global handle for menu times
    return;
}

public N_SP_MenuReasons(Handle:plugin, numparams)
{
    // return a global handle for menu reasons
    return;
}

public N_SP_RegPunishForward(Handle:plugin, numParams) {
    decl String:sType[SP_MAXLEN_TYPE], String:sArrayString[SP_MAXLEN_TYPE];
    GetNativeString(1, sType, sizeof(sType));
    for(new i = 0; i<GetArraySize(g_hRegPunishPlugins);i++)
    {
        GetArrayString(g_hRegPunishTypes, i, sArrayString, sizeof(sArrayString));
        if(StrEqual(sArrayString, sType) && plugin == GetArrayCell(g_hRegPunishPlugins, i))
            return false;
    }
    PushArrayCell(g_hRegPunishPlugins, plugin);
    PushArrayString(g_hRegPunishTypes, sType);
    PushArrayCell(g_hRegPunishCallbacks, GetNativeCell(2));
    return true;
}

public N_SP_DeRegPunishForward(Handle:plugin, numParams) {
    decl String:sType[SP_MAXLEN_TYPE], String:sArrayString[SP_MAXLEN_TYPE];
    GetNativeString(1, sType, sizeof(sType));
    for(new i = 0; i<GetArraySize(g_hRegPunishTypes);i++)
    {
        GetArrayString(g_hRegPunishTypes, i, sArrayString, sizeof(sArrayString));
        if(StrEqual(sArrayString, sType) && plugin == GetArrayCell(g_hRegPunishPlugins, i))
        {
            RemoveFromArray(g_hRegPunishPlugins, i);
            RemoveFromArray(g_hRegPunishTypes, i);
            RemoveFromArray(g_hRegPunishCallbacks, i);
            return true;
        }
    }
    return false;
}

public N_SP_ClientHasAvtivePunishment(Handle:plugin, numParams)
{
    // need Auth, IP, PunishType, callback
    // possibly allow this to check all connected clients for when the plugin is loaded mid-game?
}

public OnClientAuthorized(client, const String:auth[])
{
    decl String:sQuery[512], String:sSafeAuth[SP_MAXLEN_AUTH*2], String:sClientIP[SP_MAXLEN_IP], String:sSafeClientIP[SP_MAXLEN_IP*2];
    GetClientIP(client, sClientIP, sizeof(sClientIP));
    SQL_EscapeString(g_hSQL, sClientIP, sSafeClientIP, sizeof(sSafeClientIP));
    SQL_EscapeString(g_hSQL, auth, sSafeAuth, sizeof(sSafeAuth));
    Format(sQuery, sizeof(sQuery), "SELECT Punish_Type, Punish_Time, Punish_Length, Punish_Auth_Type, Punish_Reason FROM %s%s WHERE ((Punish_Time + (Punish_Length*60)) > %d OR Punish_Length = 0) AND UnPunish = 0 AND IF(Punish_Auth_Type=0, Punish_Player_ID = '%s', Punish_Player_IP = '%s') AND IF(Punish_All_Servers=1, IF(Punish_All_Mods=0, Punish_Server_ID IN (SELECT ID FROM sp_servers WHERE Server_Mod = %d), 1), Punish_Server_ID=%d) ORDER BY FIELD(Punish_Length, 0), Punish_Time DESC, Punish_Length DESC", g_sDBPrefix, SP_DB_NAME, GetTime(), sSafeAuth, sSafeClientIP, g_iModID, g_iServerID);
    SQL_TQuery(g_hSQL, Query_ClientAuthFetch, sQuery, GetClientUserId(client));
}

public Query_ClientAuthFetch(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
    if (hndl == INVALID_HANDLE)
    {
        LogError("Database Error in Query_ClientAuthFetch: %s", error);
        return;
    }
    new client = GetClientOfUserId(userid);
    if (client == 0)
        return;

    decl String:sReason[SP_MAXLEN_REASON], String:sType[SP_MAXLEN_TYPE];
    new iStartTime;
    new iLength;
    new iAuthType;
    while (SQL_FetchRow(hndl))
    {  
        SQL_FetchString(hndl, 0, sType, sizeof(sType));
        iStartTime = SQL_FetchInt(hndl, 1);
        iLength = SQL_FetchInt(hndl, 2);
        iAuthType = SQL_FetchInt(hndl, 3);
        SQL_FetchString(hndl, 4, sReason, sizeof(sReason));
        decl String:sArrayString[SP_MAXLEN_TYPE];
        for(new i = 0; i<GetArraySize(g_hRegPunishTypes);i++)
        {
            GetArrayString(g_hRegPunishTypes, i, sArrayString, sizeof(sArrayString));
            if(StrEqual(sArrayString, sType))
            {
                new Handle:f = CreateForward(ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_String);
                AddToForward(f, GetArrayCell(g_hRegPunishPlugins, i), Function:GetArrayCell(g_hRegPunishCallbacks, i));
                Call_StartForward(f);
                Call_PushCell(userid);
                Call_PushCell(iStartTime);
                Call_PushCell(iLength);
                Call_PushCell(iAuthType);
                Call_PushString(sReason);
                Call_Finish();
                CloseHandle(f);
            }
        }
    }
}

public N_SP_DB_AddPunish(Handle:plugin, numparams)
{
    decl String:sPunishType[SP_MAXLEN_TYPE], String:sPunishReason[SP_MAXLEN_REASON];

    new PunishedUserID = GetNativeCell(1);
    new PunisherUserID = GetNativeCell(2);
    new PunishLength = GetNativeCell(3);
    new PunishAuthType = GetNativeCell(4);
    GetNativeString(5, sPunishType, sizeof(sPunishType));
    GetNativeString(6, sPunishReason, sizeof(sPunishReason));

    new Punished = GetClientOfUserId(PunishedUserID);
    new Punisher = GetClientOfUserId(PunisherUserID);

    decl String:sPunishedName[MAX_TARGET_LENGTH], String:sPunishedAuth[SP_MAXLEN_AUTH], String:sPunishedIP[SP_MAXLEN_IP], String:sPunisherName[MAX_TARGET_LENGTH], String:sPunisherAuth[SP_MAXLEN_AUTH];

    GetClientName(Punished, sPunishedName, sizeof(sPunishedName));
    GetClientName(Punisher, sPunisherName, sizeof(sPunisherName));
    GetClientAuthString(Punished, sPunishedAuth, sizeof(sPunishedAuth));
    GetClientAuthString(Punisher, sPunisherAuth, sizeof(sPunisherAuth));
    GetClientIP(Punished, sPunishedIP, sizeof(sPunishedIP));

    decl String:sSPunishedName[MAX_TARGET_LENGTH*2], String:sSPunishedAuth[SP_MAXLEN_AUTH*2], String:sSPunishedIP[SP_MAXLEN_IP*2], String:sSPunisherName[MAX_TARGET_LENGTH*2], String:sSPunisherAuth[SP_MAXLEN_AUTH*2], String:sSPunishReason[SP_MAXLEN_REASON*2], String:sSPunishType[SP_MAXLEN_TYPE*2];

    SQL_EscapeString(g_hSQL, sPunishedName, sSPunishedName, sizeof(sSPunishedName));
    SQL_EscapeString(g_hSQL, sPunisherName, sSPunisherName, sizeof(sSPunisherName));
    SQL_EscapeString(g_hSQL, sPunishedAuth, sSPunishedAuth, sizeof(sSPunishedAuth));
    SQL_EscapeString(g_hSQL, sPunisherAuth, sSPunisherAuth, sizeof(sSPunisherAuth));
    SQL_EscapeString(g_hSQL, sPunishedIP, sSPunishedIP, sizeof(sSPunishedIP));
    SQL_EscapeString(g_hSQL, sPunishType, sSPunishType, sizeof(sSPunishType));
    SQL_EscapeString(g_hSQL, sPunishReason, sSPunishReason, sizeof(sSPunishReason));
    
    new iSPunishAuthType = 0;
    if(PunishAuthType == 1)
        iSPunishAuthType = 1;

    decl String:sQuery[512];
    Format(sQuery, sizeof(sQuery), "INSERT INTO %s%s (Punish_Time, Punish_Server_ID, Punish_Player_Name, Punish_Player_ID, Punish_Player_IP, Punish_Auth_Type, Punish_Type, Punish_Length, Punish_Reason, Punish_All_Servers, Punish_All_Mods, Punish_Admin_Name, Punish_Admin_ID) VALUES (%d, %d, '%s', '%s', '%s', %d, '%s', %d, '%s', %d, %d, '%s', '%s')", g_sDBPrefix, SP_DB_NAME, GetTime(), g_iServerID, sSPunishedName, sSPunishedAuth, sSPunishedIP, iSPunishAuthType, sSPunishType, PunishLength, sSPunishReason, g_bPunishAllServers, g_bPunishAllMods, sSPunisherName, sSPunisherAuth);
    SQL_TQuery(g_hSQL, Query_AddPunish, sQuery, 0);
}

public Query_AddPunish(Handle:owner, Handle:hndl, const String:error[], any:data)
{
    if (hndl == INVALID_HANDLE)
    {
        LogError("Database Error in Query_AddPunish: %s", error);
        return;
    }
}

public N_SP_DB_UnPunish(Handle:plugin, numparams)
{
    decl String:sUnPunishType[SP_MAXLEN_TYPE], String:sUnPunishReason[SP_MAXLEN_REASON];

    new PunishedUserID = GetNativeCell(1);
    new UnPunisherUserID = GetNativeCell(2);
    new PunishAuthType = GetNativeCell(3);
    GetNativeString(4, sUnPunishType, sizeof(sUnPunishType));
    GetNativeString(5, sUnPunishReason, sizeof(sUnPunishReason));

    new Punished = GetClientOfUserId(PunishedUserID);
    new UnPunisher = GetClientOfUserId(UnPunisherUserID);

    decl String:sPunishedAuth[SP_MAXLEN_AUTH], String:sPunishedIP[SP_MAXLEN_IP], String:sUnPunisherName[MAX_TARGET_LENGTH], String:sUnPunisherAuth[SP_MAXLEN_AUTH];

    GetClientName(UnPunisher, sUnPunisherName, sizeof(sUnPunisherName));
    GetClientAuthString(Punished, sPunishedAuth, sizeof(sPunishedAuth));
    GetClientAuthString(UnPunisher, sUnPunisherAuth, sizeof(sUnPunisherAuth));
    GetClientIP(Punished, sPunishedIP, sizeof(sPunishedIP));

    decl String:sSPunishedAuth[SP_MAXLEN_AUTH*2], String:sSPunishedIP[SP_MAXLEN_IP*2], String:sSUnPunisherName[MAX_TARGET_LENGTH*2], String:sSUnPunisherAuth[SP_MAXLEN_AUTH*2], String:sSUnPunishReason[SP_MAXLEN_REASON*2], String:sSUnPunishType[SP_MAXLEN_TYPE*2];

    SQL_EscapeString(g_hSQL, sUnPunisherName, sSUnPunisherName, sizeof(sSUnPunisherName));
    SQL_EscapeString(g_hSQL, sPunishedAuth, sSPunishedAuth, sizeof(sSPunishedAuth));
    SQL_EscapeString(g_hSQL, sUnPunisherAuth, sSUnPunisherAuth, sizeof(sSUnPunisherAuth));
    SQL_EscapeString(g_hSQL, sPunishedIP, sSPunishedIP, sizeof(sSPunishedIP));
    SQL_EscapeString(g_hSQL, sUnPunishType, sSUnPunishType, sizeof(sSUnPunishType));
    SQL_EscapeString(g_hSQL, sUnPunishReason, sSUnPunishReason, sizeof(sSUnPunishReason));
    
    decl String:sAuthQuery[50];
    
    new iSUnPunishAuthType = 0;
    if(PunishAuthType == 1)
    {
        iSUnPunishAuthType = 1;
        Format(sAuthQuery, sizeof(sAuthQuery), "Punish_Player_IP='%s'", sPunishedIP);
    } else {
        Format(sAuthQuery, sizeof(sAuthQuery), "Punish_Player_ID='%s'", sSPunishedAuth);
    }
    
    decl String:sQuery[512];
    Format(sQuery, sizeof(sQuery), "UPDATE %s%s SET UnPunish=1, UnPunish_Admin_name='%s', UnPunish_Admin_ID='%s', UnPunish_Time=%d, UnPunish_Reason='%s' WHERE Punish_Type='%s' AND ((Punish_Time + (Punish_Length*60)) > %d OR Punish_Length = 0) AND UnPunish = 0 AND Punish_Auth_Type=%d AND %s AND IF(Punish_All_Servers=1, IF(Punish_All_Mods=0, Punish_Server_ID IN (SELECT ID FROM sp_servers WHERE Server_Mod = %d), 1), Punish_Server_ID=%d)", g_sDBPrefix, SP_DB_NAME, sSUnPunisherName, sSUnPunisherAuth, GetTime(), sSUnPunishReason, sUnPunishType, GetTime(), iSUnPunishAuthType, sAuthQuery, g_iModID, g_iServerID);
    SQL_TQuery(g_hSQL, Query_UnPunish, sQuery, 0);
}

public Query_UnPunish(Handle:owner, Handle:hndl, const String:error[], any:data)
{
    if (hndl == INVALID_HANDLE)
    {
        LogError("Database Error in Query_UnPunish: %s", error);
        return;
    }
}