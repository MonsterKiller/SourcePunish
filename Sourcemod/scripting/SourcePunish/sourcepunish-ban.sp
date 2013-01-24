#pragma semicolon 1

#include <sourcepunish>
#include <sourcemod>

public Plugin:myinfo = 
{
    name = "SourcePunish -> Ban",
    author = "Monster Killer",
    description = "Punishment tool",
    version = SP_PLUGIN_VERSION,
    url = SP_PLUGIN_URL
};

public OnPluginStart()
{
    LoadTranslations("sourcepunish-ban.phrases");
    LoadTranslations("common.phrases");
    
    new bool:bPluginSourcePunish = LibraryExists("sourcepunish");
    if(bPluginSourcePunish)
        RegisterPluginTypes();

    RegAdminCmd("sm_ban", Command_Ban, ADMFLAG_BAN, "Ban ");
    //RegAdminCmd("sm_banip", Command_BanIP, ADMFLAG_BAN, "Ban ");
    //RegAdminCmd("sm_addban", Command_BanAdd, ADMFLAG_BAN, "Ban ");
}

public SP_Loaded()
{
    RegisterPluginTypes();
}

public RegisterPluginTypes()
{
    SP_RegPunishForward("ban", Forward_Ban);
}

public OnPluginEnd()
{
    SP_DeRegPunishForward("ban");
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
                Time = (starttime + (length * 60)) -  GetTime();
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
        // We should show a ban menu here
        
    } else if(args < 2 || args > 3)
    {
		ReplyToCommand(client, "%s Usage: sm_ban <#userid|name> <time> [reason]", SP_PREFIX);
		return Plugin_Handled;
    } else {
        decl String:sPlayer[SP_MAXLEN_NAME], String:sLength[15], String:sReason[SP_MAXLEN_REASON];
        GetCmdArg(1, sPlayer, sizeof(sPlayer));
        GetCmdArg(2, sLength, sizeof(sLength));
        GetCmdArg(3, sReason, sizeof(sReason));
        
        new target = FindTarget(0, sPlayer, true, false);
        if(target == -1)
        {
            //ReplyToCommand(client, "%s Player not found", SP_PREFIX);
            return Plugin_Handled;
        }
    }
    return Plugin_Handled;
}