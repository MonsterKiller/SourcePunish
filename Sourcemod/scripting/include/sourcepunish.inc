#if defined _sourcepunish_included
  #endinput
#endif
#define _sourcepunish_included

#define SP_PLUGIN_VERSION "0.1.0"
#define SP_PLUGIN_URL "http://sourcepunish.net"
#define SP_PREFIX "[\x07FF0000SP\x01]"
#define SP_PREFIX_NOCOLOR "[SP]"

#define SP_MAXLEN_TIME 20 // The maximum length of a time string
#define SP_MAXLEN_TYPE 16 // The maximum length of a time string
#define SP_MAXLEN_REASON 70 // The maximum length of a reason string

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
 * Registers a punishment type to this plugin
 *
 * @param type      String containing type to register
 * @param callback  A function to use as a callback for when a client connects with this active punishment type
 * @noreturn
 */
native SP_RegPunishForward(const String:type[], SPClientConnect:callback);

/**
 * Deregisters a punishment type to this plugin
 *
 * @param type      String containing type to deregister
 * @noreturn
 */
native SP_DeRegPunishForward(const String:type[]);

/**
 * Called when the main plugin is loaded/reloaded
**/
forward SP_Loaded();

/**
 * Works out the time as a string
 *
 * @param time        Time int
 * @param timestring  String to store formatted time in
 * @param maxlen      Maximum length of the timestring
 */
native bool:SP_TimeToString(time, String:timestring[], maxlen);

/**
 * Log a punishment in the SQL database
 *
 * @param PunishedID     UserID of the punished player.
 * @param PunisherID     UserID of the punisher.
 * @param PunishTime     Time (in seconds) the punishment should last, -1 if no time (E.G. a kick).
 * @param PunishAuthType Punish by SteamID (0) or IP address (1).
 * @param PunishType     Punishment to apply as a string (E.G. "kick").
 * @param PunishReason   Reason the player is being punished.
 * @return               True on success, else false.
 */
native bool:SP_SQL_AddPunish(PunishedID, PunisherID, PunishTime, PunishAuthType, const String:PunishType[], const String:PunishReason[]);