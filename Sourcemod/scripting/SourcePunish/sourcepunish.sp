#pragma semicolon 1

#include <sourcepunish>
#include <sourcemod>
#include <sdktools>
#include <regex>

new Handle:g_hRegPunish;
enum eRegPunish
{
    String:Types[32],
    Handle:Callbacks,
    Handle:Plugins
};

new Handle:g_hSPMenu;
enum eSPMenu
{
    String:Items[32],
    String:Commands[32],
    Flags,
    Handle:Plugins
};

new Handle:g_hKV;
new Handle:g_hSQL = INVALID_HANDLE;

new Handle:g_hrSteamID;
new Handle:g_hrIP;

new g_iServerID;
new g_iModID;
new g_bPunishAllServers;
new g_bPunishAllMods;
new String:g_sDBPrefix[30];

public Plugin:myinfo = 
{
    name = "SourcePunish -> Core",
    author = SP_PLUGIN_AUTHOR,
    description = "Punishment tool",
    version = SP_PLUGIN_VERSION,
    url = SP_PLUGIN_URL
};

public OnPluginStart()
{
    LoadTranslations("sourcepunish.phrases");
    CreateConVar("sourcepunish_version", SP_PLUGIN_VERSION, "Current version of SourcePunish", FCVAR_PLUGIN|FCVAR_REPLICATED|FCVAR_SPONLY|FCVAR_NOTIFY);

    SP_LoadConfig();

    g_hRegPunish = CreateArray(_:eRegPunish);
    g_hSPMenu = CreateArray(_:eSPMenu);

    RegAdminCmd("sm_sp", Command_SP, ADMFLAG_GENERIC, "sp");
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
    ClearArray(g_hSPMenu);
    ClearArray(g_hRegPunish);
    CloseHandle(g_hSQL);
    CloseHandle(g_hKV);
    CloseHandle(g_hrSteamID);
    CloseHandle(g_hrIP);
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    CreateNative("SP_Reply", N_SP_Reply);
    CreateNative("SP_FindTarget", N_SP_FindTarget);
    CreateNative("SP_TimeToString", N_SP_TimeToString);
    CreateNative("SP_StringToTime", N_SP_StringToTime);
    CreateNative("SP_IsValidSteamId", N_SP_IsValidSteamId);
    CreateNative("SP_IsValidIp", N_SP_IsValidIP);
    CreateNative("SP_RegPunishForward", N_SP_RegPunishForward);
    CreateNative("SP_DeRegPunishForward", N_SP_DeRegPunishForward);
    CreateNative("SP_RegMenuItem", N_SP_RegMenuItem);
    CreateNative("SP_DeRegMenuItem", N_SP_DeRegMenuItem);
    CreateNative("SP_DB_AddPunish", N_SP_DB_AddPunish);
    CreateNative("SP_DB_UnPunish", N_SP_DB_AddPunish);
    CreateNative("SP_Menu_Players", N_SP_Menu_Players);
    CreateNative("SP_Menu_Times", N_SP_Menu_Times);
    CreateNative("SP_Menu_Reasons", N_SP_Menu_Reasons);
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
    
    g_hrSteamID = CompileRegex("STEAM_[0-7]:[01]:[0-9]{7,10}", PCRE_CASELESS); //future proofed
    g_hrIP = CompileRegex("(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3}");

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

public N_SP_Reply(Handle:plugin, numparams)
{
    decl String:sTextBuffer[512], iWritten;
    new client = GetNativeCell(1);
    GetNativeString(2, sTextBuffer, sizeof(sTextBuffer));
    FormatNativeString(0, 2, 3, sizeof(sTextBuffer), iWritten, sTextBuffer);
    if(client == 0)
        ReplyToCommand(client, "%s%s", SP_PREFIX_NOCOLOR, sTextBuffer);
    else if(client > 0) {
        if(!IsFakeClient(client) && IsClientConnected(client))
            ReplyToCommand(client, "%s%s", SP_PREFIX, sTextBuffer);
    }
}

public N_SP_FindTarget(Handle:plugin, numparams)
{
    decl String:sTarget[MAX_TARGET_LENGTH], String:sTargetString[MAX_TARGET_LENGTH];
    new iTriggerClient = GetNativeCell(1);
    GetNativeString(2, sTarget, sizeof(sTarget));
    new bool:bSteamID = GetNativeCell(3);
    new bool:bNoBots = GetNativeCell(4);
    new bool:bImmunity = GetNativeCell(5);

    new flags = COMMAND_FILTER_NO_MULTI;
    flags |= COMMAND_FILTER_NO_IMMUNITY;

    decl TargetList[1], bool:tn_is_ml;
    
    new iTargetMatchs = 0;
    new iTargetMatch = -1;

    if(bSteamID)
    {
        if(SP_IsValidSteamId(sTarget))
        {
            decl String:sTempAuth[SP_MAXLEN_AUTH];
            for(new i = 1; i<= MaxClients; i++)
            {
                if(!IsClientConnected(i))
                    continue;
                GetClientAuthString(i, sTempAuth, sizeof(sTempAuth));
                if(StrEqual(sTarget, sTempAuth, false))
                {
                    if(bImmunity)
                    {
                        if(CanUserTarget(iTriggerClient, i))
                        {
                            iTargetMatchs+=1;
                            iTargetMatch = i;
                        } else {
                            SP_Reply(iTriggerClient, "%t", "SP Cannot Target");
                            return -1;
                        }
                    } else {
                        iTargetMatchs+=1;
                        iTargetMatch = i;
                    }
                }
            }
        }
    }
    if(ProcessTargetString(sTarget, iTriggerClient, TargetList, 1, flags, sTargetString, sizeof(sTargetString), tn_is_ml) > 0)
    {
        if(bImmunity)
        {
            if(!CanUserTarget(iTriggerClient, TargetList[0]))
            {
                SP_Reply(iTriggerClient, "%t", "SP Cannot Target");
                return -1;
            }
        }
        if(bNoBots)
        {
            if(IsFakeClient(TargetList[0]))
            {
                SP_Reply(iTriggerClient, "%t", SP_PREFIX_NOCOLOR, "SP Cannot Target Bot");
                return -1;
            }
        }
        iTargetMatchs+=1;
        iTargetMatch = TargetList[0];
    }
    if(iTargetMatchs == 1)
        return iTargetMatch;
    if(iTargetMatchs > 1)
        SP_Reply(iTriggerClient, "%t", "SP Multi Target");
    else
        SP_Reply(iTriggerClient, "%t", "SP Bad Target");
    return -1;
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

public N_SP_StringToTime(Handle:plugin, numparams)
{
    decl String:sTime[20];
    GetNativeString(1, sTime, sizeof(sTime));
    new client = GetNativeCell(2);
    if(client > 0)
    {
        if(!IsClientConnected(client))
            client = -1;
    }
    if(StrEqual(sTime, "0"))
        return 0;
    new iTime = StringToInt(sTime);
    if(iTime < 1)
    {
        if(client >= 0)
            SP_Reply(client, "%t", "SP Time Invalid String");
        return -1;
    }
    return (iTime*60);
}

public N_SP_IsValidSteamId(Handle:plugin, numparams)
{
    decl String:sSteamID[SP_MAXLEN_AUTH];
    GetNativeString(1, sSteamID, sizeof(sSteamID));
    new iRegex = MatchRegex(g_hrSteamID, sSteamID);
    if(iRegex >= 0)
        return true;
    else
        return false;
}

public N_SP_IsValidIP(Handle:plugin, numparams)
{
    decl String:sIP[SP_MAXLEN_IP];
    GetNativeString(1, sIP, sizeof(sIP));
    new iRegex = MatchRegex(g_hrIP, sIP);
    if(iRegex > 0)
        return true;
    else
        return false;
}

public N_SP_Menu_Times(Handle:plugin, numparams)
{
    new Handle:hTmpMenuHandle = GetNativeCell(1);
    if(hTmpMenuHandle == INVALID_HANDLE)
        return _:hTmpMenuHandle;

    KvRewind(g_hKV);
    if(!KvJumpToKey(g_hKV, "MenuTimes") || !KvGotoFirstSubKey(g_hKV, false)) {
        LogError("%t", "SP Menu No Times");
        return _:hTmpMenuHandle;
    }

    decl String:key[20], String:value[20];
    do
    {
        KvGetSectionName(g_hKV, key, sizeof(key));
        KvGetString(g_hKV, NULL_STRING, value, sizeof(value));
        AddMenuItem(hTmpMenuHandle, value, key);
    } while (KvGotoNextKey(g_hKV, false));
    KvRewind(g_hKV);

    return _:hTmpMenuHandle;
}

public N_SP_Menu_Reasons(Handle:plugin, numparams)
{
    new Handle:hTmpMenuHandle = GetNativeCell(1);
    if(hTmpMenuHandle == INVALID_HANDLE)
        return _:hTmpMenuHandle;

    KvRewind(g_hKV);
    if(!KvJumpToKey(g_hKV, "MenuReasons") || !KvGotoFirstSubKey(g_hKV, false)) {
        LogError("%t", "SP Menu No Reasons");
        return _:hTmpMenuHandle;
    }

    decl String:key[40], String:value[40];
    do
    {
        KvGetSectionName(g_hKV, key, sizeof(key));
        KvGetString(g_hKV, NULL_STRING, value, sizeof(value));
        AddMenuItem(hTmpMenuHandle, value, key);
    } while (KvGotoNextKey(g_hKV, false));
    KvRewind(g_hKV);

    return _:hTmpMenuHandle;
}
public N_SP_Menu_Players(Handle:plugin, numparams)
{
    decl String:sTmpName[MAX_TARGET_LENGTH], String:sTmpID[3];
    new Handle:hTmpMenuHandle = GetNativeCell(1);
    if(hTmpMenuHandle == INVALID_HANDLE)
        return _:hTmpMenuHandle;
    new client = GetNativeCell(2);
    new bool:bNoBots = GetNativeCell(3);
    new bool:bImmunity = GetNativeCell(4);
    for(new i = 1; i<= MaxClients; i++)
    {
        if(!IsClientInGame(i))
            continue;
        if(bNoBots)
        {
            if(IsFakeClient(i))
                continue;
        }
        if(bImmunity)
        {
            if(!CanUserTarget(client, i))
                continue;
        }
        GetClientName(i, sTmpName, sizeof(sTmpName));
        IntToString(GetClientUserId(i), sTmpID, sizeof(sTmpID));
        AddMenuItem(hTmpMenuHandle, sTmpID, sTmpName);
    }
    return _:hTmpMenuHandle;
}

public N_SP_RegPunishForward(Handle:plugin, numParams) {
    decl PunishHolder[eRegPunish], String:sType[SP_MAXLEN_TYPE];
    GetNativeString(1, sType, sizeof(sType));
    for(new i = 0; i < GetArraySize(g_hRegPunish); i++)
    {
        GetArrayArray(g_hRegPunish, i, PunishHolder[0]);
        if(StrEqual(PunishHolder[Types], sType, false) && plugin == PunishHolder[Plugins])
            return false;
    }
    Format(PunishHolder[Types], sizeof(PunishHolder[Types]), sType);
    PunishHolder[Callbacks] = GetNativeCell(2);
    PunishHolder[Plugins] = plugin;
    PushArrayArray(g_hRegPunish, PunishHolder[0]);
    return true;
}

public N_SP_DeRegPunishForward(Handle:plugin, numParams) {
    decl PunishHolder[eRegPunish], String:sType[SP_MAXLEN_TYPE];
    GetNativeString(1, sType, sizeof(sType));
    for(new i = 0; i < GetArraySize(g_hRegPunish); i++)
    {
        GetArrayArray(g_hRegPunish, i, PunishHolder[0]);
        if(StrEqual(PunishHolder[Types], sType, false) && plugin == PunishHolder[Plugins])
        {
            RemoveFromArray(g_hRegPunish, i);
            return true;
        }
    }
    return false;
}

public N_SP_RegMenuItem(Handle:plugin, numParams) {
    decl MenuHolder[eSPMenu], String:sItemCommand[32];
    GetNativeString(1, sItemCommand, sizeof(sItemCommand));
    for(new i = 0; i < GetArraySize(g_hSPMenu); i++)
    {
        GetArrayArray(g_hSPMenu, i, MenuHolder[0]);
        if(StrEqual(MenuHolder[Commands], sItemCommand, false) && plugin == MenuHolder[Plugins])
            return false;
    }
    Format(MenuHolder[Commands], sizeof(MenuHolder[Commands]), sItemCommand);
    GetNativeString(2, MenuHolder[Items], sizeof(MenuHolder[Items]));
    MenuHolder[Flags] = GetNativeCell(3);
    MenuHolder[Plugins] = plugin;
    PushArrayArray(g_hSPMenu, MenuHolder[0]);
    SortADTArray(g_hSPMenu, Sort_Ascending, Sort_String);
    return true;
}

public N_SP_DeRegMenuItem(Handle:plugin, numParams) {
    decl MenuHolder[eSPMenu], String:sItemCommand[32];
    GetNativeString(1, sItemCommand, sizeof(sItemCommand));
    for(new i = 0; i < GetArraySize(g_hSPMenu); i++)
    {
        GetArrayArray(g_hSPMenu, i, MenuHolder[0]);
        if(StrEqual(MenuHolder[Commands], sItemCommand, false) && plugin == MenuHolder[Plugins])
        {
            RemoveFromArray(g_hSPMenu, i);
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
// allow plugins to create a punishment time so we dont need to query for bans etc every time?
    if(!StrEqual(auth, "BOT", false) && !IsFakeClient(client))
    {
        decl String:sQuery[512], String:sSafeAuth[SP_MAXLEN_AUTH*2], String:sClientIP[SP_MAXLEN_IP], String:sSafeClientIP[SP_MAXLEN_IP*2];
        GetClientIP(client, sClientIP, sizeof(sClientIP));
        SQL_EscapeString(g_hSQL, sClientIP, sSafeClientIP, sizeof(sSafeClientIP));
        SQL_EscapeString(g_hSQL, auth, sSafeAuth, sizeof(sSafeAuth));
        Format(sQuery, sizeof(sQuery), "SELECT Punish_Type, Punish_Time, Punish_Length, Punish_Auth_Type, Punish_Reason FROM %s%s WHERE ((Punish_Time + (Punish_Length)) > %d OR Punish_Length = 0) AND UnPunish = 0 AND IF(Punish_Auth_Type=0, Punish_Player_ID = '%s', Punish_Player_IP = '%s') AND IF(Punish_All_Servers=1, IF(Punish_All_Mods=0, Punish_Server_ID IN (SELECT ID FROM sp_servers WHERE Server_Mod = %d), 1), Punish_Server_ID=%d) ORDER BY FIELD(Punish_Length, 0), Punish_Time DESC, Punish_Length DESC", g_sDBPrefix, SP_DB_NAME, GetTime(), sSafeAuth, sSafeClientIP, g_iModID, g_iServerID);
        SQL_TQuery(g_hSQL, Query_ClientAuthFetch, sQuery, GetClientUserId(client));
    }
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
        decl PunishHolder[eRegPunish];
        for(new i = 0; i < GetArraySize(g_hRegPunish); i++)
        {
            GetArrayArray(g_hRegPunish, i, PunishHolder[0]);
            if(StrEqual(PunishHolder[Types], sType, false))
            {
                new Handle:f = CreateForward(ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_String);
                AddToForward(f, PunishHolder[Plugins], Function:PunishHolder[Callbacks]);
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
// Add some kind of redundancy for if query fails?
// Store queries, mark as active, failed or delete on callback, timer to re-try failed queries?
    decl String:sPunishType[SP_MAXLEN_TYPE], String:sPunishReason[SP_MAXLEN_REASON];

    new Punished = GetNativeCell(1);
// Add a setting to log bots?
    if(IsFakeClient(Punished))
        return;
    new Punisher = GetNativeCell(2);
    new PunishLength = GetNativeCell(3);
    new PunishAuthType = GetNativeCell(4);
    GetNativeString(5, sPunishType, sizeof(sPunishType));
    GetNativeString(6, sPunishReason, sizeof(sPunishReason));

    decl String:sPunishedName[MAX_TARGET_LENGTH], String:sPunishedAuth[SP_MAXLEN_AUTH], String:sPunishedIP[SP_MAXLEN_IP], String:sPunisherName[MAX_TARGET_LENGTH], String:sPunisherAuth[SP_MAXLEN_AUTH];

    GetClientName(Punished, sPunishedName, sizeof(sPunishedName));
    GetClientName(Punisher, sPunisherName, sizeof(sPunisherName));
    GetClientAuthString(Punished, sPunishedAuth, sizeof(sPunishedAuth));
    if(Punisher == 0)
    {
        new iIp = GetConVarInt(FindConVar("hostip"));
        Format(sPunisherAuth, sizeof(sPunisherAuth), "%i.%i.%i.%i:%d", (iIp >> 24) & 0x000000FF, (iIp >> 16) & 0x000000FF, (iIp >>  8) & 0x000000FF, iIp & 0x000000FF, GetConVarInt(FindConVar("hostport")));
    } else
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
    } else
        Format(sAuthQuery, sizeof(sAuthQuery), "Punish_Player_ID='%s'", sSPunishedAuth);
    
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

public Action:Command_SP(client, args)
{ 
    new AdminId:iAdmID = GetUserAdmin(client);
    if(iAdmID == INVALID_ADMIN_ID)
        return Plugin_Handled;
    new iFlags = GetAdminFlags(iAdmID, Access_Effective);

    new Handle:hMenu = CreateMenu(MenuHandler_SPAdmin);
    SetMenuTitle(hMenu, "SP Admin Menu");
    decl MenuHolder[eSPMenu];
    for(new i = 0; i < GetArraySize(g_hSPMenu); i++)
    {
        GetArrayArray(g_hSPMenu, i, MenuHolder[0]);
        if(iFlags & MenuHolder[Flags] || iFlags & ADMFLAG_ROOT)
        {
            AddMenuItem(hMenu, MenuHolder[Commands], MenuHolder[Items]);
        }
    }
    DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
    return Plugin_Continue;
}

public MenuHandler_SPAdmin(Handle:menu, MenuAction:action, param1, param2)
{
	if(action == MenuAction_Select)
	{
        decl String:sMenuCommand[32];
        GetMenuItem(menu, param2, sMenuCommand, sizeof(sMenuCommand));
        FakeClientCommandEx(param1, sMenuCommand);
    }
}