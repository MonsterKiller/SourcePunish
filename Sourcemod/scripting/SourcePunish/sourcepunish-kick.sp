#pragma semicolon 1

#include <sourcepunish>
#include <sourcemod>

public Plugin:myinfo = 
{
    name = "SourcePunish -> Kick",
    author = SP_PLUGIN_AUTHOR,
    description = "SourcePunish kick module",
    version = SP_PLUGIN_VERSION,
    url = SP_PLUGIN_URL
};

public OnPluginStart()
{
    LoadTranslations("sourcepunish-kick.phrases");
    LoadTranslations("common.phrases");

    if(LibraryExists("sourcepunish"))
        RegisterPluginMenu();

    RegAdminCmd("sm_kick", Command_Kick, ADMFLAG_KICK, "sm_kick <#userid|steamid|name> [reason]");
}

public SP_Loaded()
{
    RegisterPluginMenu();
}

public RegisterPluginMenu()
{
    SP_RegMenuItem("sm_kick", "Kick", ADMFLAG_KICK);
}

public OnPluginEnd()
{
    SP_DeRegMenuItem("sm_kick");
}

public Action:Command_Kick(client, args)
{
    if(args == 0)
    {
        // should show a menu here
        return Plugin_Handled;
    }
    decl String:sPlayer[MAX_TARGET_LENGTH], String:sArgString[256];
    GetCmdArgString(sArgString, sizeof(sArgString));
    new iPos = BreakString(sArgString, sPlayer, sizeof(sPlayer));

    new target = SP_FindTarget(client, sPlayer, true, false);
    if(target == -1)
        return Plugin_Handled;
    
    decl String:sReason[SP_MAXLEN_REASON];
    if(iPos < 0)
        Format(sReason, sizeof(sReason), "");
    else
        Format(sReason, sizeof(sReason), sArgString[iPos]);


    if(IsClientConnected(target) && !IsClientInKickQueue(target))
    {
        SP_DB_AddPunish(target, client, -1, 0, "kick", sReason);
        GetClientName(target, sPlayer, sizeof(sPlayer));
        if(StrEqual(sReason, ""))
        {
            KickClient(target, "%t", "SP Kick Noname");
            LogAction(client, target, "%t", "SP Kick Noname");
            ShowActivity2(client, SP_PREFIX, "%t", "SP Kick", sPlayer);
        } else {
            KickClient(target, "%t", "SP Kick Noname Reason", sReason);
            LogAction(client, target, "%t", "SP Kick Noname Reason", sReason);
            ShowActivity2(client, SP_PREFIX, "%t", "SP Kick Reason", sPlayer, sReason);
        }
    } else {
        ReplyToCommand(client, "%s%t", SP_PREFIX, "SP Kick Queue");
    }
    return Plugin_Handled;
}