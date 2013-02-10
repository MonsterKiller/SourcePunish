#pragma semicolon 1

#include <sourcepunish>
#include <sourcemod>

public Plugin:myinfo = 
{
    name = "SourcePunish -> Ban",
    author = SP_PLUGIN_AUTHOR,
    description = "SourcePunish ban module",
    version = SP_PLUGIN_VERSION,
    url = SP_PLUGIN_URL
};

public OnPluginStart()
{
    LoadTranslations("sourcepunish-ban.phrases");
    LoadTranslations("common.phrases");

    if(LibraryExists("sourcepunish"))
        RegisterPlugin();

    RegAdminCmd("sm_ban", Command_Ban, ADMFLAG_BAN, "Ban ");
    //RegAdminCmd("sm_banip", Command_BanIP, ADMFLAG_BAN, "Ban ");
    //RegAdminCmd("sm_addban", Command_BanAdd, ADMFLAG_BAN, "Ban ");
}

public SP_Loaded()
{
    RegisterPlugin();
}

public RegisterPlugin()
{
    SP_RegPunishForward("ban", Forward_Ban);
    SP_RegMenuItem("sm_ban", "Ban", ADMFLAG_BAN);
}

public OnPluginEnd()
{
    SP_DeRegPunishForward("ban");
    SP_DeRegMenuItem("sm_ban");
}

public Action:Forward_Ban(userid, starttime, length, authtype, String:reason[])
{
    new client = GetClientOfUserId(userid);
    if(client)
    {
        if(IsClientConnected(client) && !IsClientInKickQueue(client))
        {
            decl String:TimeString[SP_MAXLEN_TIME];
            new Time = 0;
            if(length > 0)
                Time = (starttime + (length)) -  GetTime();
            SP_TimeToString(Time, TimeString, sizeof(TimeString));
            if(StrEqual(reason, ""))
                KickClient(client, "%t", "SP Ban Noname", TimeString);
            else
                KickClient(client, "%t", "SP Ban Noname Reason", TimeString, reason);
        }
    }
}

public Action:Command_Ban(client, args)
{
    if(args == 0)
    {
        // should show a menu here
        return Plugin_Handled;
    }
    if(args < 2)
    {
		ReplyToCommand(client, "%sUsage: sm_ban <#userid|steamid|name> <time> [reason]", SP_PREFIX);
		return Plugin_Handled;
    }
    decl String:sPlayer[MAX_TARGET_LENGTH], String:sTime[10], String:sArgString[256];
    GetCmdArgString(sArgString, sizeof(sArgString));
    new iPos = BreakString(sArgString, sPlayer, sizeof(sPlayer));
    iPos += BreakString(sArgString[iPos], sTime, sizeof(sTime));

    new iTime = SP_StringToTime(sTime, client);
    new target = SP_FindTarget(client, sPlayer, true);
    if(target == -1 || iTime == -1)
        return Plugin_Handled;
    
    decl String:TimeString[SP_MAXLEN_TIME];
    SP_TimeToString(iTime, TimeString, sizeof(TimeString));
    
    decl String:sReason[SP_MAXLEN_REASON];
    if(iPos < 0)
        Format(sReason, sizeof(sReason), "");
    else
        Format(sReason, sizeof(sReason), sArgString[iPos]);


    if(IsClientConnected(target) && !IsClientInKickQueue(target))
    {
        SP_DB_AddPunish(target, client, iTime, 0, "ban", sReason);
        GetClientName(target, sPlayer, sizeof(sPlayer));
        if(StrEqual(sReason, ""))
        {
            KickClient(target, "%t", "SP Ban Noname", TimeString);
            LogAction(client, target, "%t", "SP Ban Noname", TimeString);
            ShowActivity2(client, SP_PREFIX, "%t", "SP Ban", sPlayer, TimeString);
        } else {
            KickClient(target, "%t", "SP Ban Noname Reason", TimeString, sReason);
            LogAction(client, target, "%t", "SP Ban Noname Reason", TimeString, sReason);
            ShowActivity2(client, SP_PREFIX, "%t", "SP Ban Reason", sPlayer, TimeString, sReason);
        }
    } else {
        ReplyToCommand(client, "%s%t", SP_PREFIX, "SP Ban Queue");
    }
    return Plugin_Handled;
}