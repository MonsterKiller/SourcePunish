#define SP_PLUGIN_VERSION "0.0.04"
#define SP_PLUGIN_URL "http://sourcepunish.net"
#define SP_PREFIX "\x01[\x07FE4444SP\x01] "
#define SP_PREFIX_NOCOLOR "[SP] "
#define SP_DB_NAME "punish"
#define SP_DB_NAME_SERVER "servers"

#define SP_MAXLEN_TIME 80 // The maximum length of a time string
#define SP_MAXLEN_TYPE 20 // The maximum length of a type string
#define SP_MAXLEN_REASON 71 // The maximum length of a reason string
#define SP_MAXLEN_AUTH 64 // The maximum length of a client auth string
#define SP_MAXLEN_IP 40 // The maximum length of a client IP string

public SharedPlugin:__pl_sourcepunish = 
{
	name = "sourcepunish",
	file = "sourcepunish.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};
 
public __pl_sourcepunish_SetNTVOptional()
{
	MarkNativeAsOptional("SP_FindTarget");
	MarkNativeAsOptional("SP_RegPunishForward");
	MarkNativeAsOptional("SP_DeRegPunishForward");
	MarkNativeAsOptional("SP_RegMenuItem");
	MarkNativeAsOptional("SP_TimeToString");
	MarkNativeAsOptional("SP_DB_AddPunish");
	MarkNativeAsOptional("SP_DB_UnPunish");
}

/**
 * Find a target
 *
 * @param client	Client who issued command
 * @param target	Client's target argument
 * @param steamid	Optional. Allow search by SteamID
 * @param nobots	Optional. Set to true if bots should NOT be targetted
 * @param immunity	Optional. Set to false to ignore target immunity.
 * @return			Index of target client, or -1 on error.
 */
native SP_FindTarget(client, const String:target[], bool:steamid=true, bool:nobots = true, bool:immunity = true);

/**
 * Called when a player joins with an active punishment.
 *
 * @param userid     The client userid
 * @param starttime  Punishment start time as a unix timestamp
 * @param length     Punishment length in minutes
 * @param authtype   Punishment auth type (0 - steamid / 1 - IP)
 * @param reason     Punishment reason
 * @noreturn
 */
functag SPClientConnect Action:public(userid, starttime, length, authtype, String:reason[]);

/**
 * Registers a punishment type for a forward when a client connects
 *
 * @param type      String containing type to register
 * @param callback  A function to use as a callback for when a client connects with this active punishment type
 * @noreturn
 */
native bool:SP_RegPunishForward(const String:type[], SPClientConnect:callback);

/**
 * Deregisters a punishment type from this plugin
 *
 * @param type      String containing type to deregister
 * @noreturn
 */
native bool:SP_DeRegPunishForward(const String:type[]);

/**
 * Register a command to include on the SourcePunish admin menu
 *
 * @param ItemCommand   The command that will be run from the menu item
 * @param ItemName      The name to give the item in the menu
 * @param RequiredFlag  The admin flag required to use the command
 * @return              True if succesfully registerd, false otherwise
 */
native bool:SP_RegMenuItem(const String:ItemCommand[], const String:ItemName[], RequiredFlag);

/**
 * Deregister a command frome the SourcePunish admin menu
 *
 * @param ItemCommand   The command that will be removed from the menu item
 * @return              True if succesfully deregisterd, false otherwise
 */
native bool:SP_DeRegMenuItem(const String:ItemCommand[]);

/**
 * Called when the main plugin is loaded
**/
forward SP_Loaded();

/**
 * Works out the time as a string
 *
 * @param time        Time int
 * @param timestring  String to store formatted time in
 * @param maxlen      Maximum length of the timestring
 * @noreturn
 */
native SP_TimeToString(time, String:timestring[], maxlen);

/**
 * Converts a number string to an int and does error handling
 *
 * @param time    Time string
 * @param client  The client to reply to with errors, -1 = no reply
 * @return        Time as an integer, -1 on failure
 */
native SP_StringToTime(String:time[], client = -1);

/**
 * Log a punishment in the SQL database
 *
 * @param Punished       Client index of the punished player.
 * @param Punisher       Client index of the punisher.
 * @param PunishTime     Time (in minutes) the punishment should last, -1 if no time (E.G. a kick).
 * @param PunishAuthType Punish by SteamID (0) or IP address (1).
 * @param PunishType     Punishment to apply as a string (E.G. "kick").
 * @param PunishReason   Reason the player is being punished.
 * @noreturn
 */
native SP_DB_AddPunish(Punished, Punisher, PunishTime, PunishAuthType, const String:PunishType[], const String:PunishReason[]);

/**
 * Unpunish a player in the SQL database
 *
 * @param PunishedID      UserID of the player to unpunish.
 * @param UnPunisherID    UserID of the unpunisher.
 * @param PunishAuthType  Unpunish by SteamID (0) or IP address (1).
 * @param PunishType      Punishment to unpunish as a string (E.G. "mute").
 * @param UnPunishReason  Reason the player is being unpunished.
 * @noreturn
 */
native SP_DB_UnPunish(PunishedID, UnPunisherID, PunishAuthType, const String:PunishType[], const String:UnPunishReason[]);