#pragma semicolon 1

#include <sourcepunish>
#include <sourcemod>

new g_MenuBufferUID[MAXPLAYERS+1];

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
    LoadTranslations("sourcepunish.phrases");
    LoadTranslations("sourcepunish-kick.phrases");

    if(LibraryExists("sourcepunish"))
        RegisterPluginMenu();

    RegAdminCmd("sm_kick", Command_Kick, ADMFLAG_KICK, "sm_kick <#userid|steamid|name> [reason]");
}

public SP_Loaded()
{
    RegisterPluginMenu();
}

RegisterPluginMenu()
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
        KickMenu(client);
        return Plugin_Continue;
    }
    decl String:sPlayer[MAX_TARGET_LENGTH], String:sArgString[256];
    GetCmdArgString(sArgString, sizeof(sArgString));
    new iPos = BreakString(sArgString, sPlayer, sizeof(sPlayer));

    new target = SP_FindTarget(client, sPlayer, true, false);
    if(target == -1)
        return Plugin_Handled;
    
    decl String:sReason[SP_MAXLEN_REASON];
    if(iPos <= 0)
        Format(sReason, sizeof(sReason), "");
    else
        Format(sReason, sizeof(sReason), sArgString[iPos]);

    PerformKick(client, target, sReason);
    return Plugin_Handled;
}

KickMenu(client)
{
    g_MenuBufferUID[client] = 0;
    new Handle:hMenu = CreateMenu(MenuHandler_Kick);
    SetMenuTitle(hMenu, "Kick Player");
    hMenu = SP_Menu_Players(hMenu, client, false);
    DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_Kick(Handle:menu, MenuAction:action, param1, param2)
{
    if(action == MenuAction_Select)
    {
        decl String:sMenuItem[20];
        GetMenuItem(menu, param2, sMenuItem, sizeof(sMenuItem));
        new target = GetClientOfUserId(StringToInt(sMenuItem));
        if(target > 0)
        {
            if(!IsClientConnected(target))
            {
                SP_Reply(param1, "%t", "SP Player Not Available");
                KickMenu(param1);
            } else {
                KickMenuReason(param1);
                g_MenuBufferUID[param1] = GetClientUserId(target);
            }
        } else {
            SP_Reply(param1, "%t", "SP Player Not Available");
            KickMenu(param1);
        }
    }
}

KickMenuReason(client)
{
    new Handle:hMenu = CreateMenu(MenuHandler_KickReason);
    SetMenuTitle(hMenu, "Kick Reason");
    hMenu = SP_Menu_Reasons(hMenu);
    DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_KickReason(Handle:menu, MenuAction:action, param1, param2)
{
    if(action == MenuAction_Select)
    {
        decl String:sMenuItem[32];
        GetMenuItem(menu, param2, sMenuItem, sizeof(sMenuItem));
        new target = GetClientOfUserId(g_MenuBufferUID[param1]);
        if(target > 0)
        {
            if(!IsClientConnected(target))
            {
                SP_Reply(param1, "%t", "SP Player Not Available");
                KickMenu(param1);
            } else {
                PerformKick(param1, target, sMenuItem);
            }
        } else {
            SP_Reply(param1, "%t", "SP Player Not Available");
            KickMenu(param1);
        }
    }
}

PerformKick(client, target, String:sReason[])
{
    if(IsClientConnected(target) && !IsClientInKickQueue(target))
    {
        decl String:sPlayer[MAX_TARGET_LENGTH];
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
        SP_Reply(client, "%t", "SP Kick Queue");
    }
}