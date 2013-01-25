#pragma semicolon 1

#include <sourcepunish>
#include <sourcemod>

public Plugin:myinfo = 
{
    name = "SourcePunish -> Kick",
    author = "Monster Killer",
    description = "SourcePunish kick module",
    version = SP_PLUGIN_VERSION,
    url = SP_PLUGIN_URL
};

public OnPluginStart()
{
    LoadTranslations("sourcepunish-kick.phrases");
    LoadTranslations("common.phrases");

    RegAdminCmd("sm_kick", Command_Kick, ADMFLAG_KICK, "sm_kick <#userid|name> [reason]");
}

public Action:Command_Kick(client, args)
{
    if(args == 0)
    {
        // We should show a kick menu here
        return Plugin_Handled;
    }

    decl String:sPlayer[MAX_TARGET_LENGTH], String:sArgString[256];
    GetCmdArgString(sArgString, sizeof(sArgString));
    new iPos = BreakString(sArgString, sPlayer, sizeof(sPlayer));

    new target = FindTarget(client, sPlayer, false);
    if(target == -1)
    {
        //ReplyToCommand(client, "%sCannot find player", SP_PREFIX);
        return Plugin_Handled;
    }

    if(IsClientConnected(target) && !IsClientInKickQueue(target))
    {
        if(!IsFakeClient(target))
            SP_DB_AddPunish(GetClientUserId(target), GetClientUserId(client), -1, 0, "kick", sArgString[iPos]);
        GetClientName(target, sPlayer, sizeof(sPlayer));
        if(StrEqual(sArgString[iPos], "")
        {
            KickClient(target, "%t", "SP Kick Noname");
            ShowActivity2(client, SP_PREFIX, "%t", "SP Kick", sPlayer);
        } else {
            KickClient(target, "%t", "SP Kick Noname Reason", sArgString[iPos]);
            ShowActivity2(client, SP_PREFIX, "%t", "SP Kick Reason", sPlayer, sArgString[iPos]);
        }
    } else {
        ReplyToCommand(client, "%s%t", SP_PREFIX, "SP Kick Queue");
    }
    return Plugin_Handled;
}