#pragma semicolon 1

#include <sourcepunish>
#include <sourcemod>

new g_MenuBufferUID[MAXPLAYERS+1];
new g_MenuBufferTime[MAXPLAYERS+1];

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
    LoadTranslations("sourcepunish.phrases");
    LoadTranslations("sourcepunish-ban.phrases");
    //LoadTranslations("common.phrases");

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
        BanMenu(client);
        return Plugin_Handled;
    }
    if(args < 2)
    {
        SP_Reply(client, "Usage: sm_ban <#userid|steamid|name> <time> [reason]");
        return Plugin_Handled;
    }
    decl String:sPlayer[MAX_TARGET_LENGTH], String:sTime[10], String:sArgString[256];
    GetCmdArgString(sArgString, sizeof(sArgString));
    new iPos = BreakString(sArgString, sPlayer, sizeof(sPlayer));
    if(iPos <= 0)
    {
        SP_Reply(client, "Usage: sm_ban <#userid|steamid|name> <time> [reason]");
        return Plugin_Handled;
    }
    new iPos2 = BreakString(sArgString[iPos], sTime, sizeof(sTime));

    new iTime = SP_StringToTime(sTime, client);
    new target = SP_FindTarget(client, sPlayer, true);
    if(target == -1 || iTime == -1)
        return Plugin_Handled;

    decl String:sReason[SP_MAXLEN_REASON];
    if(iPos2 <= 0)
        Format(sReason, sizeof(sReason), "");
    else
        Format(sReason, sizeof(sReason), sArgString[iPos+iPos2]);

    PerformBan(client, target, iTime, sReason, 0);
    return Plugin_Handled;
}

BanMenu(client)
{
    g_MenuBufferUID[client] = 0;
    g_MenuBufferTime[client] = 0;
    new Handle:hMenu = CreateMenu(MenuHandler_Ban);
    SetMenuTitle(hMenu, "Ban Player");
    hMenu = SP_Menu_Players(hMenu, client);
    DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_Ban(Handle:menu, MenuAction:action, param1, param2)
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
                BanMenu(param1);
            } else {
                BanMenuTime(param1);
                g_MenuBufferUID[param1] = GetClientUserId(target);
            }
        } else {
            SP_Reply(param1, "%t", "SP Player Not Available");
            BanMenu(param1);
        }
    }
}

BanMenuTime(client)
{
    new Handle:hMenu = CreateMenu(MenuHandler_BanTime);
    SetMenuTitle(hMenu, "Ban Time");
    hMenu = SP_Menu_Times(hMenu);
    DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_BanTime(Handle:menu, MenuAction:action, param1, param2)
{
    if(action == MenuAction_Select)
    {
        decl String:sMenuItem[20];
        GetMenuItem(menu, param2, sMenuItem, sizeof(sMenuItem));
        g_MenuBufferTime[param1] = SP_StringToTime(sMenuItem);
        BanMenuReason(param1);
    }
}

BanMenuReason(client)
{
    new Handle:hMenu = CreateMenu(MenuHandler_BanReason);
    SetMenuTitle(hMenu, "Ban Reason");
    hMenu = SP_Menu_Reasons(hMenu);
    DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_BanReason(Handle:menu, MenuAction:action, param1, param2)
{
    if(action == MenuAction_Select)
    {
        decl String:sMenuItem[32];
        GetMenuItem(menu, param2, sMenuItem, sizeof(sMenuItem));
        new iTime = g_MenuBufferTime[param1];
        new target = GetClientOfUserId(g_MenuBufferUID[param1]);
        if(target > 0)
        {
            if(!IsClientConnected(target))
            {
                SP_Reply(param1, "%t", "SP Kick Not Available");
                BanMenu(param1);
            } else {
                PerformBan(param1, target, iTime, sMenuItem, 0);
            }
        } else {
            SP_Reply(param1, "%t", "SP Kick Not Available");
            BanMenu(param1);
        }
    }
}

PerformBan(client, target, iTime, String:sReason[], iAuthType)
{
    decl String:TimeString[SP_MAXLEN_TIME];
    SP_TimeToString(iTime, TimeString, sizeof(TimeString));
    
    if(IsClientConnected(target) && !IsClientInKickQueue(target))
    {
        decl String:sPlayer[MAX_TARGET_LENGTH];
        SP_DB_AddPunish(target, client, iTime, iAuthType, "ban", sReason);
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
        SP_Reply(client, "%t", "SP Ban Queue");
    }
}