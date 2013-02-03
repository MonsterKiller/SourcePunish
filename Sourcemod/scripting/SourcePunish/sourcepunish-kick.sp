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
    RegAdminCmd("sm_kicksteam", Command_KickSteam, ADMFLAG_KICK, "sm_kicksteam <steamid> [reason]");
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
        return Plugin_Handled;

    if(IsClientConnected(target) && !IsClientInKickQueue(target))
    {
        if(!IsFakeClient(target))
            SP_DB_AddPunish(GetClientUserId(target), GetClientUserId(client), -1, 0, "kick", sArgString[iPos]);
        GetClientName(target, sPlayer, sizeof(sPlayer));
        if(StrEqual(sArgString[iPos], ""))
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


public Action:Command_KickSteam(client, args)
{
    if(args == 0)
    {
        // We should show a kick menu here
        return Plugin_Handled;
    }

    decl String:sPlayer[MAX_TARGET_LENGTH], String:sPlayerAuth[SP_MAXLEN_AUTH], String:sTempAuth[SP_MAXLEN_AUTH], String:sArgString[256];
    GetCmdArgString(sArgString, sizeof(sArgString));
    new iPos = BreakString(sArgString, sPlayerAuth, sizeof(sPlayerAuth));

    for(new i = 1; i<= MAXPLAYERS; i++)
    {
        GetClientAuthString(i, sTempAuth, sizeof(sTempAuth));
        if(StrEqual(sPlayerAuth, sTempAuth, false))
        {
            if(IsClientConnected(i) && !IsClientInKickQueue(i))
            {
                if(!IsFakeClient(i))
                    SP_DB_AddPunish(GetClientUserId(i), GetClientUserId(client), -1, 0, "kick", sArgString[iPos]);
                GetClientName(i, sPlayer, sizeof(sPlayer));
                if(StrEqual(sArgString[iPos], ""))
                {
                    KickClient(i, "%t", "SP Kick Noname");
                    ShowActivity2(client, SP_PREFIX, "%t", "SP Kick", sPlayer);
                } else {
                    KickClient(i, "%t", "SP Kick Noname Reason", sArgString[iPos]);
                    ShowActivity2(client, SP_PREFIX, "%t", "SP Kick Reason", sPlayer, sArgString[iPos]);
                }
                return Plugin_Handled;
            } else {
                ReplyToCommand(client, "%s%t", SP_PREFIX, "SP Kick Queue");
            }
        }
    }
    ReplyToCommand(client, "%s%t", SP_PREFIX, "SP Kick Steam");
    return Plugin_Handled;
}