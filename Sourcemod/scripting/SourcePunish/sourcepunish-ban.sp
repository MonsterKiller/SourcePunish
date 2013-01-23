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

//    RegAdminCmd("sm_ban", Command_Ban, ADMFLAG_BAN, "Ban ");
}

public SP_Loaded()
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
        decl String:TimeString[SP_MAXLEN_TIME];
        new Time = 0;
        if(length > 0)
            Time = (starttime + (length * 60)) -  GetTime();
        //Time = RoundToNearest(Time);
        SP_TimeToString(Time, TimeString, SP_MAXLEN_TIME);
        if(StrEqual(reason, ""))
            KickClient(client, "%t", "SP Ban Noname", TimeString);
        else
            KickClient(client, "%t", "SP Ban Noname Reason", TimeString, reason);
        
    }
}