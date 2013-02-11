#pragma semicolon 1

#include <sourcepunish>
#include <sourcemod>
#include <sdktools>

new g_MenuBufferUID[MAXPLAYERS+1];
new g_MenuBufferTime[MAXPLAYERS+1];
new g_MenuBufferType[MAXPLAYERS+1];

#define TYPE_GAG 1
#define TYPE_UNGAG -1
#define TYPE_MUTE 2
#define TYPE_UNMUTE -2
#define TYPE_SILENCE 3
#define TYPE_UNSILENCE -3

new g_isGagged[MAXPLAYERS+1];
new g_isMuted[MAXPLAYERS+1];
new g_isSilenced[MAXPLAYERS+1];

new Handle:g_hGagTimers[MAXPLAYERS+1];
new Handle:g_hMuteTimers[MAXPLAYERS+1];
new Handle:g_hSilenceTimers[MAXPLAYERS+1];

new Handle:g_hDeadTalk;

public Plugin:myinfo = 
{
    name = "SourcePunish -> Mute",
    author = SP_PLUGIN_AUTHOR,
    description = "SourcePunish mute module",
    version = SP_PLUGIN_VERSION,
    url = SP_PLUGIN_URL
};

public OnPluginStart()
{
    LoadTranslations("sourcepunish.phrases");
    //LoadTranslations("common.phrases");

    if(LibraryExists("sourcepunish"))
        RegisterPlugin();

    AddCommandListener(Listener_Say, "say");
    AddCommandListener(Listener_Say, "say2");
    AddCommandListener(Listener_Say, "say_team");

    RegAdminCmd("sm_gag", Command_Gag, ADMFLAG_CHAT, "Gag ");
    RegAdminCmd("sm_ungag", Command_UnGag, ADMFLAG_CHAT, "Gag ");
    RegAdminCmd("sm_mute", Command_Mute, ADMFLAG_CHAT, "Mute ");
    RegAdminCmd("sm_unmute", Command_UnMute, ADMFLAG_CHAT, "Mute ");
    RegAdminCmd("sm_silence", Command_Silence, ADMFLAG_CHAT, "Silence ");
    RegAdminCmd("sm_unsilence", Command_UnSilence, ADMFLAG_CHAT, "Silence ");
}

public OnAllPluginsLoaded()
{
    g_hDeadTalk = FindConVar("sm_deadtalk");
}

public SP_Loaded()
{
    RegisterPlugin();
}

public RegisterPlugin()
{
    SP_RegPunishForward("Gag", Forward_Gag);
    SP_RegMenuItem("sm_gag", "Gag", ADMFLAG_CHAT);
}

public OnPluginEnd()
{
    SP_DeRegPunishForward("gag");
    SP_DeRegMenuItem("sm_gag");
}

public Action:Listener_Say(client, const String:sCommand[], args)
{
    if (g_isGagged[client] || g_isSilenced[client])
        return Plugin_Stop;
    return Plugin_Continue;
}

public Action:Command_Gag(client, args)
{
    return HandleCommand(client, args, TYPE_GAG);
}

public Action:Command_UnGag(client, args)
{
    return HandleUnCommand(client, args, TYPE_UNGAG);
}

public Action:Command_Mute(client, args)
{
    return HandleCommand(client, args, TYPE_MUTE);
}

public Action:Command_UnMute(client, args)
{
    return HandleUnCommand(client, args, TYPE_UNMUTE);
}

public Action:Command_Silence(client, args)
{
    return HandleCommand(client, args, TYPE_SILENCE);
}

public Action:Command_UnSilence(client, args)
{
    return HandleUnCommand(client, args, TYPE_UNSILENCE);
}

Action:HandleCommand(client, args, type)
{
    if(args == 0)
    {
        Menu(client, type);
        return Plugin_Handled;
    }

    decl String:szCommand[16];
    GetCmdArg(0, szCommand, sizeof(szCommand));
    if(args < 2)
    {
        SP_Reply(client, "Usage: %s <#userid|steamid|name> <time> [reason]", szCommand);
        return Plugin_Handled;
    }
    decl String:sPlayer[MAX_TARGET_LENGTH], String:sTime[10], String:sArgString[256];
    GetCmdArgString(sArgString, sizeof(sArgString));
    new iPos = BreakString(sArgString, sPlayer, sizeof(sPlayer));
    if(iPos <= 0)
    {
        SP_Reply(client, "Usage: %s <#userid|steamid|name> <time> [reason]", szCommand);
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

    Perform(client, target, iTime, type, sReason, 0);
    return Plugin_Handled;
}

Action:HandleUnCommand(client, args, type)
{
    if(args == 0)
    {
        Menu(client, type);
        return Plugin_Handled;
    }

    decl String:szCommand[16];
    GetCmdArg(0, szCommand, sizeof(szCommand));
    if(args < 1)
    {
        SP_Reply(client, "Usage: %s <#userid|steamid|name> [reason]", szCommand);
        return Plugin_Handled;
    }
    decl String:sPlayer[MAX_TARGET_LENGTH], String:sArgString[256];
    GetCmdArgString(sArgString, sizeof(sArgString));
    new iPos = BreakString(sArgString, sPlayer, sizeof(sPlayer));
    if(iPos <= 0)
    {
        SP_Reply(client, "Usage: %s <#userid|steamid|name> [reason]", szCommand);
        return Plugin_Handled;
    }

    new target = SP_FindTarget(client, sPlayer, true);
    if(target == -1)
        return Plugin_Handled;

    decl String:sReason[SP_MAXLEN_REASON];
    if(iPos <= 0)
        Format(sReason, sizeof(sReason), "");
    else
        Format(sReason, sizeof(sReason), sArgString[iPos]);

    Perform(client, target, 0, type, sReason, 0);
    return Plugin_Handled;
}

public Action:Forward_Gag(userid, starttime, length, authtype, String:reason[])
{
    new client = GetClientOfUserId(userid);
    if(client)
    {
        if(IsClientConnected(client))
        {
            g_isGagged[client] = true;
        }
    }
}

Menu(client, type)
{
    g_MenuBufferUID[client] = 0;
    g_MenuBufferTime[client] = 0;
    g_MenuBufferType[client] = type;
    new Handle:hMenu = CreateMenu(MenuHandler);
    switch (type)
    {
        case TYPE_GAG:
            SetMenuTitle(hMenu, "Gag Player");
        case TYPE_UNGAG:
            SetMenuTitle(hMenu, "UnGag Player");
        case TYPE_MUTE:
            SetMenuTitle(hMenu, "Mute Player");
        case TYPE_UNMUTE:
            SetMenuTitle(hMenu, "UnMute Player");
        case TYPE_SILENCE:
            SetMenuTitle(hMenu, "Silence Player");
        case TYPE_UNSILENCE:
            SetMenuTitle(hMenu, "UnSilence Player");
    }
    hMenu = SP_Menu_Players(hMenu, client);
    DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler(Handle:menu, MenuAction:action, param1, param2)
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
                Menu(param1, g_MenuBufferType[param1]);
            } else {
                g_MenuBufferUID[param1] = GetClientUserId(target);
                if (g_MenuBufferType[param1] > 0)
                    MenuTime(param1);
                else
                    MenuReason(param1);
            }
        } else {
            SP_Reply(param1, "%t", "SP Player Not Available");
            Menu(param1, g_MenuBufferType[param1]);
        }
    }
}

MenuTime(client)
{
    new Handle:hMenu = CreateMenu(MenuHandler_Time);
    switch (g_MenuBufferType[client])
    {
        case TYPE_GAG:
            SetMenuTitle(hMenu, "Gag Time");
        case TYPE_MUTE:
            SetMenuTitle(hMenu, "Mute Time");
        case TYPE_SILENCE:
            SetMenuTitle(hMenu, "Silence Time");
    }
    hMenu = SP_Menu_Times(hMenu);
    DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_Time(Handle:menu, MenuAction:action, param1, param2)
{
    if(action == MenuAction_Select)
    {
        decl String:sMenuItem[20];
        GetMenuItem(menu, param2, sMenuItem, sizeof(sMenuItem));
        g_MenuBufferTime[param1] = SP_StringToTime(sMenuItem);
        MenuReason(param1);
    }
}

MenuReason(client)
{
    new Handle:hMenu = CreateMenu(MenuHandler_Reason);
    switch (g_MenuBufferType[client])
    {
        case TYPE_GAG:
            SetMenuTitle(hMenu, "Gag Reason");
        case TYPE_UNGAG:
            SetMenuTitle(hMenu, "UnGag Reason");
        case TYPE_MUTE:
            SetMenuTitle(hMenu, "Mute Reason");
        case TYPE_UNMUTE:
            SetMenuTitle(hMenu, "UnMute Reason");
        case TYPE_SILENCE:
            SetMenuTitle(hMenu, "Silence Reason");
        case TYPE_UNSILENCE:
            SetMenuTitle(hMenu, "UnSilence Reason");
    }
    hMenu = SP_Menu_Reasons(hMenu);
    DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_Reason(Handle:menu, MenuAction:action, param1, param2)
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
                SP_Reply(param1, "%t", "SP Player Not Available");
                Menu(param1, g_MenuBufferType[param1]);
            } else {
                Perform(param1, target, iTime, g_MenuBufferType[param1], sMenuItem, 0);
            }
        } else {
            SP_Reply(param1, "%t", "SP Player Not Available");
            Menu(param1, g_MenuBufferType[param1]);
        }
    }
}

Perform(client, target, iTime, type, String:sReason[], iAuthType)
{
    decl String:TimeString[SP_MAXLEN_TIME];
    SP_TimeToString(iTime, TimeString, sizeof(TimeString));
    decl String:sPlayer[MAX_TARGET_LENGTH];
    GetClientName(target, sPlayer, sizeof(sPlayer));

    switch (type)
    {
        case TYPE_GAG:
        {
            SP_DB_AddPunish(target, client, iTime, iAuthType, "gag", sReason);
            LogAction(client, target, "%t", "SP Gag Noname", TimeString);
            ShowActivity2(client, SP_PREFIX, "%t", "SP Gag", sPlayer, TimeString);
            g_isGagged[target] = true;
            g_hGagTimers[target] = CreateTimer(float(iTime), Timer_UnGag, target);
        }
        case TYPE_UNGAG:
        {
            SP_DB_UnPunish(target, client, iAuthType, "gag", sReason);
            LogAction(client, target, "%t", "SP UnGag Noname", TimeString);
            ShowActivity2(client, SP_PREFIX, "%t", "SP UnGag", sPlayer, TimeString);
            g_isGagged[target] = false;
        }
        case TYPE_MUTE:
        {
            SP_DB_AddPunish(target, client, iTime, iAuthType, "mute", sReason);
            LogAction(client, target, "%t", "SP Mute Noname", TimeString);
            ShowActivity2(client, SP_PREFIX, "%t", "SP Mute", sPlayer, TimeString);
            SetClientListeningFlags(target, VOICE_MUTED);
            g_isMuted[client] = true;
            g_hMuteTimers[target] = CreateTimer(float(iTime), Timer_UnMute, target);
        }
        case TYPE_UNMUTE:
        {
            SP_DB_UnPunish(target, client, iAuthType, "mute", sReason);
            LogAction(client, target, "%t", "SP UnMute Noname", TimeString);
            ShowActivity2(client, SP_PREFIX, "%t", "SP UnMute", sPlayer, TimeString);
            g_isMuted[target] = false;
            if (GetConVarInt(g_hDeadTalk) == 1 && !IsPlayerAlive(target))
                SetClientListeningFlags(target, VOICE_LISTENALL);
            else if (GetConVarInt(g_hDeadTalk) == 2 && !IsPlayerAlive(target))
                SetClientListeningFlags(target, VOICE_TEAM);
            else
                SetClientListeningFlags(target, VOICE_NORMAL);
        }
        case TYPE_SILENCE:
        {
            SP_DB_AddPunish(target, client, iTime, iAuthType, "silence", sReason);
            LogAction(client, target, "%t", "SP Silence Noname", TimeString);
            ShowActivity2(client, SP_PREFIX, "%t", "SP Silence", sPlayer, TimeString);
            SetClientListeningFlags(target, VOICE_MUTED);
            g_isSilenced[client] = true;
            g_hSilenceTimers[target] = CreateTimer(float(iTime), Timer_UnSilence, target);
        }
        case TYPE_UNSILENCE:
        {
            SP_DB_UnPunish(target, client, iAuthType, "mute", sReason);
            LogAction(client, target, "%t", "SP UnMute Noname", TimeString);
            ShowActivity2(client, SP_PREFIX, "%t", "SP UnMute", sPlayer, TimeString);
            g_isSilenced[target] = false;
            if (GetConVarInt(g_hDeadTalk) == 1 && !IsPlayerAlive(target))
                SetClientListeningFlags(target, VOICE_LISTENALL);
            else if (GetConVarInt(g_hDeadTalk) == 2 && !IsPlayerAlive(target))
                SetClientListeningFlags(target, VOICE_TEAM);
            else
                SetClientListeningFlags(target, VOICE_NORMAL);
        }
    }
}

public Action:Timer_UnSilence(Handle:timer, any:client)
{
    g_isSilenced[client] = false;
    if (GetConVarInt(g_hDeadTalk) == 1 && !IsPlayerAlive(client))
        SetClientListeningFlags(client, VOICE_LISTENALL);
    else if (GetConVarInt(g_hDeadTalk) == 2 && !IsPlayerAlive(client))
        SetClientListeningFlags(client, VOICE_TEAM);
    else
        SetClientListeningFlags(client, VOICE_NORMAL);
}

public Action:Timer_UnMute(Handle:timer, any:client)
{
    g_isMuted[client] = false;
    if (GetConVarInt(g_hDeadTalk) == 1 && !IsPlayerAlive(client))
        SetClientListeningFlags(client, VOICE_LISTENALL);
    else if (GetConVarInt(g_hDeadTalk) == 2 && !IsPlayerAlive(client))
        SetClientListeningFlags(client, VOICE_TEAM);
    else
        SetClientListeningFlags(client, VOICE_NORMAL);
}

public Action:Timer_UnGag(Handle:timer, any:client)
{
    g_isGagged[client] = false;
}

public OnClientDisconnect(client)
{
	if (g_hSilenceTimers[client] != INVALID_HANDLE)
	{
		KillTimer(g_hSilenceTimers[client]);
		g_hSilenceTimers[client] = INVALID_HANDLE;
	}
	if (g_hMuteTimers[client] != INVALID_HANDLE)
	{
		KillTimer(g_hMuteTimers[client]);
		g_hMuteTimers[client] = INVALID_HANDLE;
	}
	if (g_hGagTimers[client] != INVALID_HANDLE)
	{
		KillTimer(g_hGagTimers[client]);
		g_hGagTimers[client] = INVALID_HANDLE;
	}
}
