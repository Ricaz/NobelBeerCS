#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <csx>
#include <engine>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <json>
#include <nvault>
#include <sockets>

#pragma ctrlchar '\'
#define PLUGIN "Nobel Beer CS"
#define AUTHOR "Nobel Kollegiet"
#define VERSION "2.0"

#define ACCESS_ADMIN ADMIN_SLAY
#define ACCESS_PUBLIC ADMIN_ALL
#define VAULT_NAME "nobel"
#define VAULT_KEY_MAPEND "mapend"
#define OVERRIDES_FILE "nobel_players.ini"
#define BOT_IDS_FILE "nobel_bot_ids.ini"

#define FREEZE_TIME 5.0
#define FROZEN_SPEED 0.1
#define FLASH_PROTECTION_TIME 8.0
#define MAPEND_PAUSE_TIME 300.0
#define ROUND_ENDING_WARNING 19.0
#define SOCKET_RETRY_DELAY 10.0

// Teleswap: chance per round that a random T and CT swap places, not before
// TELESWAP_EARLIEST seconds into the round
#define TELESWAP_CHANCE 20
#define TELESWAP_EARLIEST 30.0

// Noob buff: free gear after this many rounds in a row without a kill (additive),
// for players in the lower half by sips with fewer kills than deaths
#define NOOBBUFF_VEST_ROUNDS 2
#define NOOBBUFF_HELMET_ROUNDS 3
#define NOOBBUFF_GRENADES_ROUNDS 4
#define NOOBBUFF_FULL_ROUNDS 5

const PRIMARY_WEAPONS = (1<<CSW_SCOUT) | (1<<CSW_XM1014) | (1<<CSW_MAC10) | (1<<CSW_AUG) | (1<<CSW_UMP45)
    | (1<<CSW_SG550) | (1<<CSW_GALIL) | (1<<CSW_FAMAS) | (1<<CSW_AWP) | (1<<CSW_MP5NAVY) | (1<<CSW_M249)
    | (1<<CSW_M3) | (1<<CSW_M4A1) | (1<<CSW_TMP) | (1<<CSW_G3SG1) | (1<<CSW_SG552) | (1<<CSW_AK47) | (1<<CSW_P90)

// Task IDs. Per-player tasks add the player id (1-32) to their base.
enum (+= 100)
{
    TASK_UNFREEZE = 100,
    TASK_RAMBO,
    TASK_ZOOMSLAP,
    TASK_PERIODIC,
    TASK_MAPEND_PAUSE,
    TASK_ROUND_ENDING,
    TASK_HURRYUP,
    TASK_BUY_CHECK,
    TASK_KIDD,
    TASK_MONEY_CHECK,
    TASK_FLASH_PROTECTION,
    TASK_MODE_ANNOUNCE,
    TASK_REPLY_POLL,
    TASK_BALANCE_TIMEOUT,
    TASK_STATS_TIMEOUT,
    TASK_STATS_REFRESH,
    TASK_TELESWAP,
    TASK_PAUSE_ACK
}

enum ModState
{
    STATE_STOPPED,
    STATE_STARTING,
    STATE_STARTED
}
new const STATE_NAME[ModState][] = { "STOPPED", "STARTING", "STARTED" }

// Admin toggles. Each one is a console command that flips the setting,
// or sets it explicitly when given an argument (e.g. "nobel_pause 0").
enum Setting
{
    SET_PAUSE,
    SET_KNIFEPAUSE,
    SET_BADUM,
    SET_FLASH,
    SET_ANTIZOOMPISTOL,
    SET_FLASHPROTECTION,
    SET_NOOBBUFF,
    SET_SIPS,
    SET_TELESWAP
}
new const SETTING_CMD[Setting][] = {
    "nobel_pause",
    "nobel_knifepause",
    "nobel_badum",
    "nobel_flash",
    "nobel_antizoompistol",
    "nobel_flashprotection",
    "nobel_noobbuff",
    "nobel_sips",
    "nobel_teleswap"
}
new const SETTING_NAME[Setting][] = {
    "pausing",
    "knifepausing",
    "badum",
    "teamflash",
    "antizoompistol",
    "flashprotection",
    "noobbuff",
    "scoreboardsips",
    "teleswap"
}
new const bool:SETTING_ANNOUNCE[Setting] = { true, true, true, false, true, true, true, true, true }
new bool:g_setting[Setting] = { false, false, true, false, false, false, true, true, false }

// Special rounds. Only one can be active or queued at a time.
enum RoundMode
{
    MODE_NORMAL,
    MODE_KNIFE,
    MODE_RAMBO,
    MODE_BONG
}
new const MODE_CMD[RoundMode][] = { "", "nobel_knife", "nobel_rambo", "nobel_bong" }
new const MODE_NAME[RoundMode][] = { "", "LAAAARJF ROUND", "RAMBO ROUND", "BONG ROUND" }
new const MODE_EVENT[RoundMode][] = { "", "leif", "rambo", "bongintro" }

new const MAP_TYPES[][] = { "de", "cs", "fy", "as", "aim", "awp" }

// Personal sounds/chat messages from nobel_players.ini
enum _:Override
{
    OV_SOUND[32],
    OV_CHAT[128]
}

new bool:g_enabled
new ModState:g_state = STATE_STOPPED
new RoundMode:g_mode = MODE_NORMAL
new RoundMode:g_nextMode = MODE_NORMAL
new bool:g_endModeAfterRound
new bool:g_paused
// A pause or unpause was sent to a client and its pauseAck hasn't come back yet
new bool:g_pauseToggling
new g_pcvarPausable
new g_pausableBefore = -1
new g_roundCount
new g_winStreakT
new g_winStreakCT
new bool:g_bombDefused
new bool:g_bombExploded
new bool:g_timeElapsed
new bool:g_aloneAnnounced
new bool:g_hostageTouched
new bool:g_teamsSwitched
new bool:g_flashThrown
new bool:g_flashProtectionActive

new bool:g_frozen[MAX_PLAYERS + 1]
new g_roundsWithoutKill[MAX_PLAYERS + 1]
new bool:g_killedThisRound[MAX_PLAYERS + 1]
// This game's sips/kills/deaths per player, from the web app
new bool:g_hasStats[MAX_PLAYERS + 1]
new g_statSips[MAX_PLAYERS + 1]
new g_statKills[MAX_PLAYERS + 1]
new g_statDeaths[MAX_PLAYERS + 1]
new bool:g_awaitingBalance
new bool:g_awaitingStats
new bool:g_warnedNoStats

// Scoreboard sips are shown in the Money column (the Account message)
new g_msgAccount
new g_roundStartMoney[MAX_PLAYERS + 1]
new g_lastWeapon[MAX_PLAYERS + 1]
new g_lastTeam[MAX_PLAYERS + 1][16]

new g_mapName[32]
new g_mapType[8]
new g_msgScreenFade
new g_pauseMenu
new g_vault = INVALID_HANDLE
new g_socket
new Float:g_socketRetryAt
new Trie:g_overrides
new Array:g_botIds
new g_botIdIndex[MAX_PLAYERS + 1] = { -1, ... }

// Cvars
new g_serverHost[64]
new g_serverPort
new g_numShield
new g_numWeed
new g_numKit
new g_includeBots

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR)

    register_event("HLTV", "on_new_round", "a", "1=0", "2=0")
    register_event("DeathMsg", "on_death", "a")
    register_event("30", "on_intermission", "a")
    register_event("TeamInfo", "on_team_info", "a")
    register_event("CurWeapon", "on_cur_weapon", "be", "1=1")
    register_event("TextMsg", "on_hostages_rescued", "a", "2&#All_Hostages_R")
    register_event("TextMsg", "on_target_saved", "a", "2&#Target_Saved")
    register_event("ScreenFade", "on_screenfade", "be", "4=255", "5=255", "6=255", "7>199")
    register_logevent("on_round_start", 2, "1=Round_Start")
    register_logevent("on_round_end", 2, "1=Round_End")
    register_logevent("on_bomb_planted", 3, "2=Planted_The_Bomb")
    register_logevent("on_bomb_defused", 3, "2=Defused_The_Bomb")
    register_logevent("on_bomb_exploded", 6, "3=Target_Bombed")
    register_logevent("on_hostage_touched", 3, "2=Touched_A_Hostage")

    RegisterHam(Ham_Spawn, "player", "on_player_spawn", 1)
    // The newer CS 1.6 scoreboard's Money column; only sent by updated game servers
    g_msgAccount = get_user_msgid("Account")
    if (g_msgAccount)
        register_message(g_msgAccount, "on_account")
    RegisterHam(Ham_CS_Player_ResetMaxSpeed, "player", "on_reset_maxspeed", 1)
    RegisterHam(Ham_Weapon_WeaponIdle, "weapon_flashbang", "on_flashbang_idle")
    RegisterHam(Ham_TraceAttack, "hostage_entity", "on_hostage_hurt")
    RegisterHam(Ham_TakeDamage, "hostage_entity", "on_hostage_hurt")
    RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_awp", "on_zoompistol_attack")
    RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_g3sg1", "on_zoompistol_attack")
    RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_sg550", "on_zoompistol_attack")

    // Slap people shooting anything but the M249 in rambo rounds
    new weaponName[32]
    new const NOSHOT_BITSUM = (1<<CSW_KNIFE) | (1<<CSW_HEGRENADE) | (1<<CSW_FLASHBANG) | (1<<CSW_SMOKEGRENADE) | (1<<CSW_M249)
    for (new weapon = CSW_P228; weapon <= CSW_P90; weapon++) {
        if (~NOSHOT_BITSUM & 1<<weapon && get_weaponname(weapon, weaponName, charsmax(weaponName)))
            RegisterHam(Ham_Weapon_PrimaryAttack, weaponName, "on_rambo_attack")
    }

    for (new Setting:s; s < Setting; s++)
        register_concmd(SETTING_CMD[s], "cmd_toggle_setting", ACCESS_ADMIN, "[0|1] - Toggle a Nobel setting.")
    for (new RoundMode:m = MODE_KNIFE; m < RoundMode; m++)
        register_concmd(MODE_CMD[m], "cmd_round_mode", ACCESS_ADMIN, "Queue a special round next round. Run again to end it after the current round.")

    register_concmd("nobel", "cmd_nobel", ACCESS_ADMIN, "View current settings.")
    register_concmd("nobel_maps", "cmd_nobel_maps", ACCESS_PUBLIC, "Lists available maps on the server.")
    register_concmd("nobel_theme", "cmd_nobel_theme", ACCESS_ADMIN, "<theme> - Change sound theme.")
    register_concmd("nobel_knife_now", "cmd_nobel_end_mode_now", ACCESS_ADMIN, "End the current special round immediately.")
    register_concmd("nobel_shuffle", "cmd_nobel_shuffle", ACCESS_ADMIN, "Shuffles all players.")
    register_concmd("nobel_balance", "cmd_nobel_balance", ACCESS_ADMIN, "<games> - Rebalance teams based on each player's last N games.")
    register_concmd("nobel_sendplayers", "cmd_nobel_sendplayers", ACCESS_ADMIN, "Sends list of players to webserver")
    register_concmd("nobel_start", "cmd_nobel_start", ACCESS_ADMIN, "Start the plugin.")
    register_concmd("nobel_serverstart", "cmd_nobel_serverstart", ACCESS_ADMIN, "")
    register_concmd("nobel_stop", "cmd_nobel_stop", ACCESS_ADMIN, "Stop the plugin.")
    register_concmd("badum", "cmd_badum", ACCESS_ADMIN, "Plays badum!")
    register_concmd("shutup", "cmd_shutup", ACCESS_ADMIN, "Plays shutup!")
    register_concmd("ready", "cmd_ready", ACCESS_ADMIN, "Plays reeady sound!")

    new pcvar = create_cvar("nobel_server_host", "localhost", _, "Host of the Nobel web server")
    bind_pcvar_string(pcvar, g_serverHost, charsmax(g_serverHost))
    hook_cvar_change(pcvar, "on_server_address_changed")
    pcvar = create_cvar("nobel_server_port", "1337", _, "UDP port of the Nobel web server")
    bind_pcvar_num(pcvar, g_serverPort)
    hook_cvar_change(pcvar, "on_server_address_changed")
    bind_pcvar_num(create_cvar("nobel_num_shield", "2", _, "Shields on one team that trigger shieldforce"), g_numShield)
    bind_pcvar_num(create_cvar("nobel_num_weed", "3", _, "Smokes on one team that trigger weed"), g_numWeed)
    bind_pcvar_num(create_cvar("nobel_num_kit", "2", _, "Defuse kits on one team that trigger kidd"), g_numKit)
    bind_pcvar_num(create_cvar("nobel_bots", "0", _, "Count bots as players (for testing)", true, 0.0, true, 1.0), g_includeBots)

    new configdir[128]
    get_configsdir(configdir, charsmax(configdir))
    server_cmd("exec %s/nobel.cfg", configdir)
    server_exec()

    get_mapname(g_mapName, charsmax(g_mapName))
    detect_map_type()

    g_msgScreenFade = get_user_msgid("ScreenFade")
    g_pcvarPausable = get_cvar_pointer("pausable")
    create_pause_menu()
    load_overrides()
    load_bot_ids()

    g_vault = nvault_open(VAULT_NAME)
    if (g_vault == INVALID_HANDLE)
        log_amx("Failed to open vault: %s", VAULT_NAME)
    else if (nvault_get(g_vault, VAULT_KEY_MAPEND) == 1)
        set_task(MAPEND_PAUSE_TIME, "task_mapend_pause_end", TASK_MAPEND_PAUSE)

    send_event_always("mapchange", g_mapName)
    log_amx("Loaded (map type %s, web app %s:%d, %d player overrides, %d bot IDs)",
        g_mapType, g_serverHost, g_serverPort, TrieGetSize(g_overrides), ArraySize(g_botIds))
}

public plugin_end()
{
    if (g_vault != INVALID_HANDLE)
        nvault_close(g_vault)
    if (g_socket)
        socket_close(g_socket)
    TrieDestroy(g_overrides)
    ArrayDestroy(g_botIds)
}

detect_map_type()
{
    copy(g_mapType, charsmax(g_mapType), "de")
    for (new i; i < sizeof MAP_TYPES; i++) {
        new len = strlen(MAP_TYPES[i])
        if (equali(g_mapName, MAP_TYPES[i], len) && g_mapName[len] == '_') {
            copy(g_mapType, charsmax(g_mapType), MAP_TYPES[i])
            break
        }
    }
}

load_overrides()
{
    g_overrides = TrieCreate()

    new path[PLATFORM_MAX_PATH]
    get_configsdir(path, charsmax(path))
    format(path, charsmax(path), "%s/%s", path, OVERRIDES_FILE)

    new file = fopen(path, "rt")
    if (!file) {
        return
    }

    new line[256], authid[MAX_AUTHID_LENGTH], situation[16], key[96], data[Override]
    while (fgets(file, line, charsmax(line))) {
        trim(line)
        if (!line[0] || line[0] == ';' || line[0] == '#')
            continue

        parse(line, authid, charsmax(authid), situation, charsmax(situation),
            data[OV_SOUND], charsmax(data[OV_SOUND]), data[OV_CHAT], charsmax(data[OV_CHAT]))
        formatex(key, charsmax(key), "%s %s", authid, situation)
        TrieSetArray(g_overrides, key, data, sizeof data)
    }
    fclose(file)

}

// Looks up a personal sound/chat message for a player in a situation ("tk", "knife").
// Leaves sound and chat untouched if there is no override.
get_override(const authid[], const situation[], sound[], soundLen, chat[], chatLen)
{
    new key[96], data[Override]
    formatex(key, charsmax(key), "%s %s", authid, situation)
    if (!TrieGetArray(g_overrides, key, data, sizeof data))
        return

    copy(sound, soundLen, data[OV_SOUND])
    copy(chat, chatLen, data[OV_CHAT])
}

// Steam IDs for bots to use instead of "BOT", so testing can use real players' stats
load_bot_ids()
{
    g_botIds = ArrayCreate(MAX_AUTHID_LENGTH)

    new path[PLATFORM_MAX_PATH]
    get_configsdir(path, charsmax(path))
    format(path, charsmax(path), "%s/%s", path, BOT_IDS_FILE)

    new file = fopen(path, "rt")
    if (!file)
        return

    new line[128], authid[MAX_AUTHID_LENGTH]
    while (fgets(file, line, charsmax(line))) {
        strtok2(line, authid, charsmax(authid), line, charsmax(line), ';', TRIM_FULL)
        if (authid[0])
            ArrayPushString(g_botIds, authid)
    }
    fclose(file)

}

// Gives a bot the first Steam ID from nobel_bot_ids.ini that no other bot uses
assign_bot_id(id)
{
    for (new i, count = ArraySize(g_botIds); i < count; i++) {
        new bool:taken
        for (new other = 1; other <= MAX_PLAYERS; other++) {
            if (g_botIdIndex[other] == i)
                taken = true
        }
        if (!taken) {
            g_botIdIndex[id] = i
            return
        }
    }
}

// Logs an admin action: "ALSTRUP (STEAM_0:1:11611559): queued a knife round".
// id 0 is the server itself: rcon, the server console or a config file.
log_admin(id, const format[], any:...)
{
    new message[192], who[96]
    vformat(message, charsmax(message), format, 3)
    if (id) {
        new authid[MAX_AUTHID_LENGTH]
        get_user_authid(id, authid, charsmax(authid))
        formatex(who, charsmax(who), "%n (%s)", id, authid)
    } else {
        copy(who, charsmax(who), "server")
    }
    log_amx("%s: %s", who, message)
}

// Appends "NAME -> TEAM" to a list of team moves for a one-line log
add_move(moves[], len, id, const team[])
{
    format(moves, len, "%s%s%n -> %s", moves, moves[0] ? ", " : "", id, team)
}

set_state(ModState:newState)
{
    log_amx("Mod state: %s -> %s", STATE_NAME[g_state], STATE_NAME[newState])
    g_state = newState
}

// ----------------------------------------------------------------------------
// Players
// ----------------------------------------------------------------------------

bool:is_counted(id)
{
    return g_includeBots || !is_user_bot(id)
}

// get_players() that skips HLTV, and bots unless nobel_bots is set
get_game_players(players[MAX_PLAYERS], &num, const extraFlags[] = "", const team[] = "")
{
    new flags[8]
    formatex(flags, charsmax(flags), "h%s%s", g_includeBots ? "" : "c", extraFlags)
    get_players(players, num, flags, team)
}

// Steam ID, or a unique fake one for bots since they all share "BOT"
get_player_id(id, out[], len)
{
    if (!is_user_bot(id))
        get_user_authid(id, out, len)
    else if (g_botIdIndex[id] != -1)
        ArrayGetString(g_botIds, g_botIdIndex[id], out, len)
    else
        formatex(out, len, "BOT_%n", id)
}

find_player_by_id(const playerId[])
{
    new players[MAX_PLAYERS], num, authid[MAX_AUTHID_LENGTH]
    get_game_players(players, num)
    for (new i; i < num; i++) {
        get_player_id(players[i], authid, charsmax(authid))
        if (equal(authid, playerId))
            return players[i]
    }
    return 0
}

public client_putinserver(id)
{
    g_frozen[id] = false
    g_roundsWithoutKill[id] = 0
    g_killedThisRound[id] = false
    g_hasStats[id] = false
    g_lastWeapon[id] = 0
    g_lastTeam[id][0] = 0
}

// Triggered when client receives STEAMID
public client_authorized(id)
{
    if (is_user_bot(id))
        assign_bot_id(id)

    if (!is_counted(id))
        return

    send_player_cmd("playerjoined", id)
}

public client_disconnected(id)
{
    g_frozen[id] = false
    remove_task(TASK_UNFREEZE + id)
    remove_task(TASK_RAMBO + id)
    remove_task(TASK_ZOOMSLAP + id)

    if (is_counted(id)) {
        send_player_cmd("playerleft", id)
    }

    g_botIdIndex[id] = -1
}

public on_team_info()
{
    new id = read_data(1)
    new team[16]
    read_data(2, team, charsmax(team))

    // TeamInfo is sent a lot, only tell the web server about actual changes
    if (!is_user_connected(id) || !is_counted(id) || equal(team, g_lastTeam[id]))
        return

    copy(g_lastTeam[id], charsmax(g_lastTeam[]), team)
    send_player_cmd("playerteam", id, team)
}

public on_player_spawn(id)
{
    if (!is_user_alive(id))
        return

    client_cmd(id, "-attack")
    g_lastWeapon[id] = 0

    if (!g_enabled)
        return

    if (g_setting[SET_FLASH]) {
        give_item(id, "weapon_flashbang")
        give_item(id, "weapon_flashbang")
    }

    if (g_mode == MODE_RAMBO) {
        strip_user_weapons(id)
        set_user_health(id, 200)
        give_item(id, "weapon_m249")
        give_item(id, "item_assaultsuit")
        give_item(id, "weapon_hegrenade")
        cs_set_user_bpammo(id, CSW_M249, 10000)
        set_task(5.0, "task_rambo", TASK_RAMBO + id, _, _, "b")
    }

    if (g_setting[SET_NOOBBUFF] && g_mode == MODE_NORMAL)
        give_noob_buff(id)
}

// Free gear for struggling players without a kill for a while. The tiers add up,
// and only missing items are given (CS allows 1 HE, 2 flashbangs and 1 smoke grenade).
give_noob_buff(id)
{
    new rounds = g_roundsWithoutKill[id]
    if (rounds < NOOBBUFF_VEST_ROUNDS || !is_struggling(id))
        return

    new given[96]
    new CsArmorType:armor
    cs_get_user_armor(id, armor)
    if (rounds >= NOOBBUFF_HELMET_ROUNDS || armor == CS_ARMOR_VESTHELM) {
        cs_set_user_armor(id, 100, CS_ARMOR_VESTHELM)
        add(given, charsmax(given), "vest + helmet")
    } else {
        cs_set_user_armor(id, 100, CS_ARMOR_KEVLAR)
        add(given, charsmax(given), "vest")
    }

    if (rounds >= NOOBBUFF_GRENADES_ROUNDS) {
        if (!user_has_weapon(id, CSW_HEGRENADE)) {
            give_item(id, "weapon_hegrenade")
            add(given, charsmax(given), ", HE")
        }
        // One flashbang, both from the full kit on
        new flashbangs = user_has_weapon(id, CSW_FLASHBANG) ? cs_get_user_bpammo(id, CSW_FLASHBANG) : 0
        new wanted = rounds >= NOOBBUFF_FULL_ROUNDS ? 2 : 1
        for (new i = flashbangs; i < wanted; i++)
            give_item(id, "weapon_flashbang")
        if (flashbangs < wanted)
            add(given, charsmax(given), wanted - flashbangs > 1 ? ", flashbangs" : ", flashbang")
    }

    if (rounds >= NOOBBUFF_FULL_ROUNDS) {
        if (!user_has_weapon(id, CSW_SMOKEGRENADE)) {
            give_item(id, "weapon_smokegrenade")
            add(given, charsmax(given), ", smoke")
        }

        new weapons[32], num
        if (!(get_user_weapons(id, weapons, num) & PRIMARY_WEAPONS) && !cs_get_user_shield(id)) {
            new bool:terrorist = cs_get_user_team(id) == CS_TEAM_T
            give_item(id, terrorist ? "weapon_ak47" : "weapon_m4a1")
            cs_set_user_bpammo(id, terrorist ? CSW_AK47 : CSW_M4A1, 90)
            add(given, charsmax(given), terrorist ? ", AK-47" : ", M4A1")
        }
    }

    // Server log only, players aren't told
    log_amx("Noob buff: %n (%d rounds without a kill, %d/%d K/D, %d sips) got %s",
        id, rounds, g_statKills[id], g_statDeaths[id], g_statSips[id], given)
}

// Fewer kills than deaths, and at least half of the players have drunk more
bool:is_struggling(id)
{
    if (!g_hasStats[id] || g_statKills[id] >= g_statDeaths[id])
        return false

    new total, higher
    for (new other = 1; other <= MAX_PLAYERS; other++) {
        if (!g_hasStats[other] || !is_user_connected(other))
            continue
        total++
        if (g_statSips[other] > g_statSips[id])
            higher++
    }
    return higher * 2 >= total
}

public on_reset_maxspeed(id)
{
    if (g_frozen[id] && is_user_alive(id))
        set_user_maxspeed(id, FROZEN_SPEED)
}

freeze_player(id)
{
    if (!is_user_alive(id))
        return

    g_frozen[id] = true
    ExecuteHamB(Ham_CS_Player_ResetMaxSpeed, id)

    remove_task(TASK_UNFREEZE + id)
    set_task(FREEZE_TIME, "task_unfreeze", TASK_UNFREEZE + id)
}

public task_unfreeze(taskid)
{
    new id = taskid - TASK_UNFREEZE
    g_frozen[id] = false

    if (is_user_alive(id)) {
        ExecuteHamB(Ham_CS_Player_ResetMaxSpeed, id)
        client_print(id, print_chat, "You can now move again.")
    }
}

// ----------------------------------------------------------------------------
// Rounds
// ----------------------------------------------------------------------------

public on_new_round()
{
    if (!g_enabled)
        return

    start_new_round()
}

start_new_round()
{
    remove_task(TASK_ROUND_ENDING)
    remove_task(TASK_HURRYUP)
    remove_task(TASK_TELESWAP)

    for (new id = 1; id <= MAX_PLAYERS; id++) {
        g_frozen[id] = false
        remove_task(TASK_UNFREEZE + id)
        remove_task(TASK_RAMBO + id)
    }
    client_cmd(0, "-attack")

    if (g_endModeAfterRound) {
        end_round_mode()
    } else if (g_nextMode != MODE_NORMAL) {
        g_mode = g_nextMode
        g_nextMode = MODE_NORMAL
    }

    if (g_mode != MODE_NORMAL)
        set_task(1.0, "task_announce_mode", TASK_MODE_ANNOUNCE)

    g_roundCount++
    g_aloneAnnounced = false
    g_hostageTouched = false

    new players[MAX_PLAYERS], num
    get_game_players(players, num)
    for (new i; i < num; i++)
        g_roundStartMoney[players[i]] = cs_get_user_money(players[i])

    if (g_mode != MODE_NORMAL)
        send_event(MODE_EVENT[g_mode])
    else
        send_event(g_roundCount == 1 ? "firstround" : "round")

    set_task(10.0, "task_money_check", TASK_MONEY_CHECK)
}

public on_round_start()
{
    send_players()

    if (!g_enabled)
        return

    send_event("roundstart")
    // Everyone drinks a sip at round start
    refresh_player_stats_soon()
    g_bombDefused = false
    g_bombExploded = false
    g_timeElapsed = false

    if (equali(g_mapName, "de_rats"))
        send_event("rats")

    if (g_setting[SET_FLASH]) {
        g_flashThrown = false
        client_cmd(0, "use weapon_flashbang")
    }

    set_task(8.0, "task_buy_check", TASK_BUY_CHECK)
    set_task(get_cvar_float("mp_roundtime") * 60.0 - ROUND_ENDING_WARNING, "task_round_ending", TASK_ROUND_ENDING)

    if (g_setting[SET_FLASHPROTECTION]) {
        g_flashProtectionActive = true
        set_task(FLASH_PROTECTION_TIME, "task_end_flash_protection", TASK_FLASH_PROTECTION)
    }

    // Some time between 30 seconds in and 5 seconds before the round timer runs out
    new Float:roundTime = get_cvar_float("mp_roundtime") * 60.0
    if (g_setting[SET_TELESWAP] && g_mode == MODE_NORMAL && random_num(1, 100) <= TELESWAP_CHANCE && roundTime - 5.0 > TELESWAP_EARLIEST)
        set_task(random_float(TELESWAP_EARLIEST, roundTime - 5.0), "task_teleswap", TASK_TELESWAP)
}

// ----------------------------------------------------------------------------
// Teleswap: a random living T and CT swap places, with a short flash
// ----------------------------------------------------------------------------

public task_teleswap()
{
    if (!g_enabled || !g_setting[SET_TELESWAP] || g_paused)
        return

    new ts[MAX_PLAYERS], cts[MAX_PLAYERS], numT, numCT
    get_game_players(ts, numT, "ae", "TERRORIST")
    get_game_players(cts, numCT, "ae", "CT")
    if (!numT || !numCT)
        return

    new first = ts[random(numT)], second = cts[random(numCT)]
    teleswap(first, second)

    new firstId[MAX_AUTHID_LENGTH], secondId[MAX_AUTHID_LENGTH]
    get_player_id(first, firstId, charsmax(firstId))
    get_player_id(second, secondId, charsmax(secondId))
    send_event("teleswap", firstId, secondId)
    log_amx("Teleswap: %n <-> %n", first, second)
}

teleswap(first, second)
{
    new Float:origin[2][3], Float:angles[2][3], bool:ducking[2]
    new players[2]
    players[0] = first
    players[1] = second
    for (new i; i < 2; i++) {
        pev(players[i], pev_origin, origin[i])
        pev(players[i], pev_v_angle, angles[i])
        ducking[i] = (pev(players[i], pev_flags) & FL_DUCKING) != 0
    }

    for (new i; i < 2; i++) {
        new id = players[i], other = 1 - i
        // Arrive crouched if the other player was, so nobody gets stuck in a vent
        if (ducking[other]) {
            set_pev(id, pev_flags, pev(id, pev_flags) | FL_DUCKING)
            engfunc(EngFunc_SetSize, id, Float:{ -16.0, -16.0, -18.0 }, Float:{ 16.0, 16.0, 18.0 })
            set_pev(id, pev_view_ofs, Float:{ 0.0, 0.0, 12.0 })
        }
        engfunc(EngFunc_SetOrigin, id, origin[other])
        set_pev(id, pev_angles, angles[other])
        set_pev(id, pev_v_angle, angles[other])
        set_pev(id, pev_fixangle, 1)
        set_pev(id, pev_velocity, Float:{ 0.0, 0.0, 0.0 })
        flash_fade(id)
    }
}

// White screen fading out over one second, like a short flashbang
flash_fade(id)
{
    message_begin(MSG_ONE, g_msgScreenFade, _, id)
    write_short(1<<12) // duration: 1 second
    write_short(0) // hold time
    write_short(0x0000) // FFADE_IN: from the color back to normal
    write_byte(255) // r
    write_byte(255) // g
    write_byte(255) // b
    write_byte(255) // a
    message_end()
}

public on_round_end()
{
    if (!g_enabled)
        return

    remove_task(TASK_ROUND_ENDING)
    remove_task(TASK_TELESWAP)

    new players[MAX_PLAYERS], aliveT, aliveCT
    get_players(players, aliveT, "ae", "TERRORIST")
    get_players(players, aliveCT, "ae", "CT")

    if (g_bombExploded || !aliveCT) {
        g_winStreakT++
        g_winStreakCT = 0
    } else if (g_bombDefused || !aliveT || g_timeElapsed) {
        g_winStreakT = 0
        g_winStreakCT++
    }

    if (g_winStreakT >= 4 || g_winStreakCT >= 4)
        send_event("winstreak")

    count_rounds_without_kill()

    // Fresh sips/kills/deaths for the noob buff when players spawn next round
    if (g_setting[SET_NOOBBUFF] || g_setting[SET_SIPS])
        request_player_stats()
}

// Sips change with every kill and round. Several deaths close together share one request.
refresh_player_stats_soon()
{
    if (g_setting[SET_SIPS] && !task_exists(TASK_STATS_REFRESH))
        set_task(0.5, "task_stats_refresh", TASK_STATS_REFRESH)
}

public task_stats_refresh()
{
    if (!g_awaitingStats)
        request_player_stats()
}

count_rounds_without_kill()
{
    new players[MAX_PLAYERS], num
    get_game_players(players, num)
    for (new i; i < num; i++) {
        new id = players[i]
        new CsTeams:team = cs_get_user_team(id)
        if (team != CS_TEAM_T && team != CS_TEAM_CT)
            continue

        g_roundsWithoutKill[id] = g_killedThisRound[id] ? 0 : g_roundsWithoutKill[id] + 1
        g_killedThisRound[id] = false
    }
}

public task_round_ending()
{
    if (g_enabled && !g_bombDefused)
        send_event("roundending")
}

public task_end_flash_protection()
{
    g_flashProtectionActive = false
}

public task_buy_check()
{
    if (!g_enabled)
        return

    new shields[CsTeams], smokes[CsTeams], kits[CsTeams]
    new players[MAX_PLAYERS], num
    get_game_players(players, num)
    for (new i; i < num; i++) {
        new id = players[i]
        new CsTeams:team = cs_get_user_team(id)
        shields[team] += cs_get_user_shield(id)
        smokes[team] += user_has_weapon(id, CSW_SMOKEGRENADE)
        kits[team] += cs_get_user_defuse(id)
    }

    if (shields[CS_TEAM_T] >= g_numShield || shields[CS_TEAM_CT] >= g_numShield)
        send_event("shieldforce")
    else if (smokes[CS_TEAM_T] >= g_numWeed || smokes[CS_TEAM_CT] >= g_numWeed)
        send_event("weed")

    if (kits[CS_TEAM_T] >= g_numKit || kits[CS_TEAM_CT] >= g_numKit)
        set_task(3.0, "task_kidd", TASK_KIDD)
}

public task_kidd()
{
    send_event("kidd")
    client_print(0, print_chat, "Kiiiiiidd!")
}

public task_money_check()
{
    new players[MAX_PLAYERS], num
    get_game_players(players, num)
    for (new i; i < num; i++) {
        new id = players[i]
        if (g_roundStartMoney[id] - cs_get_user_money(id) >= 5500) {
            send_event("rich")
            return
        }
    }
}

public task_periodic()
{
    if (!g_enabled)
        return

    client_cmd(0, "volume 0")

    if (!g_teamsSwitched && get_timeleft() < get_cvar_num("mp_timelimit") * 30)
        switch_teams()
}

switch_teams()
{
    g_teamsSwitched = true
    send_event("teamswitch")

    new players[MAX_PLAYERS], num, newVip
    get_game_players(players, num)
    for (new i; i < num; i++) {
        new id = players[i]
        cs_set_user_vip(id, 0, 0, 1)

        switch (cs_get_user_team(id)) {
            case CS_TEAM_T: {
                cs_set_user_team(id, CS_TEAM_CT)
                newVip = id
            }
            case CS_TEAM_CT: {
                cs_set_user_team(id, CS_TEAM_T)
            }
        }

        if (user_has_weapon(id, CSW_C4))
            engclient_cmd(id, "drop", "weapon_c4")
    }

    if (equal(g_mapType, "as") && newVip)
        cs_set_user_vip(newVip, 1, 1, 1)

    if (equal(g_mapType, "as") && newVip)
        log_amx("Half-time: swapped the teams of %d players, %n is VIP", num, newVip)
    else
        log_amx("Half-time: swapped the teams of %d players", num)
}

public on_intermission()
{
    if (!g_enabled)
        return

    if (g_vault != INVALID_HANDLE)
        nvault_set(g_vault, VAULT_KEY_MAPEND, "1")
    send_event("mapend")
}

public task_mapend_pause_end()
{
    if (g_vault != INVALID_HANDLE)
        nvault_set(g_vault, VAULT_KEY_MAPEND, "0")

    // Only if the next game hasn't started already
    if (g_state == STATE_STOPPED)
        send_event_always("mapend_pause_end")
}

// ----------------------------------------------------------------------------
// Special rounds (knife, rambo, bong)
// ----------------------------------------------------------------------------

end_round_mode()
{
    if (g_mode != MODE_NORMAL)
        client_print(0, print_chat, "Nobel %s disabled!", MODE_NAME[g_mode])

    if (g_mode == MODE_RAMBO) {
        for (new id = 1; id <= MAX_PLAYERS; id++)
            remove_task(TASK_RAMBO + id)
        client_cmd(0, "-attack")
    }

    g_mode = MODE_NORMAL
    g_nextMode = MODE_NORMAL
    g_endModeAfterRound = false
    remove_task(TASK_MODE_ANNOUNCE)
}

csay(const color[], const text[])
{
    server_cmd("amx_csay %s %s", color, text)
}

announce_mode_queued(RoundMode:mode)
{
    switch (mode) {
        case MODE_KNIFE: {
            csay("green", "NEXT ROUND IS LAAAARJF ROUND !!!!! Knife only!!")
            csay("red", "NEXT ROUND IS LAAAARJF ROUND !!!!! Knife only!!")
            csay("blue", "NEXT ROUND IS LAAAARJF ROUND !!!!! Knife only!!")
            csay("red", "FAT DET !!!")
        }
        case MODE_RAMBO: {
            csay("green", "NEXT ROUND IS RAMBO ROUND !!!!!")
            csay("red", "NEXT ROUND IS RAMBO ROUND !!!!!")
            csay("blue", "RATATATATATATATA !!!!")
            csay("red", "FAT DET !!!")
        }
        case MODE_BONG: announce_bong()
    }
    server_exec()
}

announce_mode_last(RoundMode:mode)
{
    new text[64]
    formatex(text, charsmax(text), "LAST %s !!!!!", MODE_NAME[mode])
    csay("green", text)
    csay("red", text)
    csay("blue", text)
    csay("red", "FAT DET !!!")
    server_exec()
}

announce_bong()
{
    csay("green", "PAS PÅ!!")
    csay("red", "DER ER BONG I LUFTEN")
    csay("blue", "drikdrikdrikdrikdrikdrikdrikdrik")
}

public task_announce_mode()
{
    switch (g_mode) {
        case MODE_KNIFE: {
            csay("green", "LAAAARJF ROUND !!!!! Knife only!!")
            csay("red", "LAAAARJF ROUND !!!!! Knife only!!")
            csay("blue", "LAAAARJF ROUND !!!!! Knife only!!")
            csay("red", "FAT DET !!!")
        }
        case MODE_RAMBO: {
            csay("green", "!! RAMBOOO RUNDEEE !!")
            csay("red", "ALLE HEDDER JOHN!1!!")
            csay("blue", "RATATATATTATATATATATATATATATATATA")
            csay("red", "TATATATATATATATATATATATATATATATAT")
        }
        case MODE_BONG: announce_bong()
    }
    server_exec()
}

public task_rambo(taskid)
{
    new id = taskid - TASK_RAMBO
    if (!is_user_alive(id))
        return

    give_item(id, "weapon_hegrenade")
    if (get_user_weapon(id) == CSW_M249) {
        client_cmd(id, "+attack")
        cs_set_weapon_ammo(find_ent_by_owner(-1, "weapon_m249", id), 100)
    } else {
        client_cmd(id, "-attack;wait;-attack")
    }
}

// Rambos cannot stop firing the M249
public on_cur_weapon(id)
{
    if (g_mode != MODE_RAMBO)
        return

    new weapon = read_data(2)
    if (weapon == g_lastWeapon[id])
        return

    g_lastWeapon[id] = weapon
    client_cmd(id, weapon == CSW_M249 ? "+attack" : "-attack")
}

public on_rambo_attack(weapon)
{
    if (g_mode == MODE_RAMBO)
        user_slap(pev(weapon, pev_owner), random_num(40, 60))
}

// ----------------------------------------------------------------------------
// Kills
// ----------------------------------------------------------------------------

public on_death()
{
    if (!g_enabled)
        return

    new killer = read_data(1)
    new victim = read_data(2)
    new bool:headshot = read_data(3) != 0
    new weapon[32]
    read_data(4, weapon, charsmax(weapon))

    if (!victim)
        return

    remove_task(TASK_RAMBO + victim)
    refresh_player_stats_soon()

    new bool:suicide = killer == victim || !killer
    new bool:knifed = bool:equal(weapon, "knife")
    new bool:grenade = bool:equal(weapon, "grenade")

    new killerName[MAX_NAME_LENGTH], victimName[MAX_NAME_LENGTH]
    new killerId[MAX_AUTHID_LENGTH], victimId[MAX_AUTHID_LENGTH]
    get_user_name(victim, victimName, charsmax(victimName))
    get_player_id(victim, victimId, charsmax(victimId))

    new bool:teamkill
    if (killer) {
        get_user_name(killer, killerName, charsmax(killerName))
        get_player_id(killer, killerId, charsmax(killerId))
        teamkill = !suicide && cs_get_user_team(killer) == cs_get_user_team(victim)
        if (!suicide && !teamkill && killer <= MAX_PLAYERS)
            g_killedThisRound[killer] = true
    }

    if (suicide) {
        if (g_mode == MODE_BONG) {
            send_event("bong", victimId, victimId, "", weapon)
            client_print(0, print_chat, "%s? drikdrikdrikdrikdrikdrikdrik", victimName)
        } else {
            send_event("suicide", victimId, "", "", weapon)
            client_print(0, print_chat, "Hehe, %s begik selvmord :>", victimName)
        }
        if (g_setting[SET_PAUSE])
            pause_game("suicide by %s", victimName)
    }
    else if (teamkill) {
        if (g_mode == MODE_BONG) {
            send_event("bong", killerId, victimId, "", weapon, headshot)
            client_print(0, print_chat, "%s? drikdrikdrikdrikdrikdrikdrik", killerName)
        } else {
            new sound[32] = "tk", chat[128]
            formatex(chat, charsmax(chat), "Kan du bunde, %s?", killerName)
            get_override(killerId, "tk", sound, charsmax(sound), chat, charsmax(chat))
            send_event("tk", killerId, victimId, sound, weapon, headshot)
            client_print(0, print_chat, "%s", chat)
        }
        pause_or_freeze(killer, "teamkill by %s", killerName)
    }
    else if (g_mode == MODE_KNIFE && !knifed && !grenade) {
        // In knife rounds we do NOT accept to be killed by a gun!
        send_event("kniferound", killerId, victimId, "", weapon, headshot)
        client_print(0, print_chat, "Bottoms up, %s!", killerName)
        pause_or_freeze(killer, "gun kill in the knife round by %s", killerName)
    }
    else if (knifed && g_mode != MODE_KNIFE) {
        new sound[32] = "knife", chat[128]
        formatex(chat, charsmax(chat), "%s got KNIFED!", victimName)
        get_override(killerId, "knife", sound, charsmax(sound), chat, charsmax(chat))
        send_event("knife", killerId, victimId, sound, weapon, headshot)
        client_print(0, print_chat, "%s", chat)

        if (g_setting[SET_KNIFEPAUSE])
            pause_or_freeze(killer, "knife kill by %s", killerName)
    }
    else if (grenade) {
        send_event("grenade", killerId, victimId, "", weapon)
        freeze_player(killer)
    }
    else {
        if (is_worst_player(killer))
            send_event("worstplayer")
        send_event(headshot ? "headshot" : "kill", killerId, victimId, "", weapon, headshot)
        freeze_player(killer)
        check_last_alive()
    }
}

bool:is_worst_player(id)
{
    if (g_roundCount <= 3)
        return false

    new players[MAX_PLAYERS], num
    get_game_players(players, num, "e", cs_get_user_team(id) == CS_TEAM_T ? "TERRORIST" : "CT")
    if (num < 2)
        return false

    new frags = get_user_frags(id)
    for (new i; i < num; i++) {
        if (players[i] != id && frags > get_user_frags(players[i]))
            return false
    }
    return true
}

check_last_alive()
{
    if (g_aloneAnnounced)
        return

    new players[MAX_PLAYERS], total, aliveT, aliveCT
    get_game_players(players, total)
    if (total < 3)
        return

    get_game_players(players, aliveT, "ae", "TERRORIST")
    get_game_players(players, aliveCT, "ae", "CT")
    if (aliveT == 1 || aliveCT == 1) {
        g_aloneAnnounced = true
        send_event("alone")
    }
}

pause_or_freeze(killer, const reason[], any:...)
{
    if (g_setting[SET_PAUSE]) {
        new why[96]
        vformat(why, charsmax(why), reason, 3)
        pause_game("%s", why)
    } else {
        freeze_player(killer)
        // Ensure that the server does not show the pause images
        send_event("unpause")
    }
}

// ----------------------------------------------------------------------------
// Pausing
// ----------------------------------------------------------------------------

create_pause_menu()
{
    g_pauseMenu = menu_create("ADMIN PAUSE MENU", "pause_menu_handler")

    // Push "Unpause" down to key 0 so it isn't pressed by accident
    for (new i; i < 9; i++)
        menu_addblank2(g_pauseMenu)
    menu_additem(g_pauseMenu, "Unpause")
    menu_setprop(g_pauseMenu, MPROP_PERPAGE, 0)
}

public pause_menu_handler(id, menu, item)
{
    if (item == 9 && g_paused) {
        log_admin(id, "unpaused the game")
        unpause_game()
    }
    return PLUGIN_HANDLED
}

// reason: e.g. "teamkill by %s"
pause_game(const reason[], any:...)
{
    if (g_paused)
        return

    new why[96]
    vformat(why, charsmax(why), reason, 2)
    log_amx("Pausing the game: %s", why)
    toggle_pause()
}

unpause_game()
{
    if (!g_paused)
        return

    client_print(0, print_chat, "Go go go!")
    send_event("unpause")
    toggle_pause()
}

// Only clients can pause the engine. Does the same as amx_pause, except it
// makes sure a human runs the command: amx_pause from the server console picks
// the first player, which may be a bot that ignores client commands.
toggle_pause()
{
    // Several pausing events can happen in one frame (e.g. one grenade killing
    // two teammates). g_paused only changes when the pauseAck arrives, so without
    // this the second event would toggle the pause right back off.
    if (g_pauseToggling)
        return

    new players[MAX_PLAYERS], num
    get_players(players, num, "ch")
    if (!num) {
        log_amx("Cannot pause: no human players on the server")
        return
    }

    // Allow pausing only until the pauseAck comes back
    g_pausableBefore = get_pcvar_num(g_pcvarPausable)
    set_pcvar_num(g_pcvarPausable, 1)
    client_cmd(players[0], "pause;pauseAck")
    g_pauseToggling = true
    // In case the pauseAck never comes (e.g. that player disconnects)
    set_task(3.0, "task_pause_ack_timeout", TASK_PAUSE_ACK)
}

public task_pause_ack_timeout()
{
    log_amx("Pausing: no confirmation from the client, giving up")
    g_pauseToggling = false
    if (g_pausableBefore != -1) {
        set_pcvar_num(g_pcvarPausable, g_pausableBefore)
        g_pausableBefore = -1
    }
}

// Both toggle_pause() and amx_pause make a client run "pause;pauseAck". admincmd
// blocks pauseAck, so this has to be the client_command forward and not register_clcmd.
public client_command(id)
{
    new cmd[16]
    read_argv(0, cmd, charsmax(cmd))
    if (!equal(cmd, "pauseAck"))
        return PLUGIN_CONTINUE

    g_paused = !g_paused
    g_pauseToggling = false
    remove_task(TASK_PAUSE_ACK)
    log_amx(g_paused ? "Game paused" : "Game resumed")
    // The web app's killfeed stops its timers while paused
    send_event(g_paused ? "paused" : "resumed")

    if (g_pausableBefore != -1) {
        set_pcvar_num(g_pcvarPausable, g_pausableBefore)
        g_pausableBefore = -1
    }

    if (g_setting[SET_PAUSE])
        show_pause_menu(g_paused)

    return PLUGIN_CONTINUE
}

show_pause_menu(bool:show)
{
    new players[MAX_PLAYERS], num
    get_players(players, num, "ch")
    for (new i; i < num; i++) {
        if (!is_user_admin(players[i]))
            continue

        if (show)
            menu_display(players[i], g_pauseMenu)
        else
            show_menu(players[i], 0, " ", 0)
    }
}

// ----------------------------------------------------------------------------
// Misc. game events
// ----------------------------------------------------------------------------

public on_target_saved()
{
    g_timeElapsed = true
}

public on_bomb_planted()
{
    if (!g_enabled)
        return

    remove_task(TASK_ROUND_ENDING)
    set_task(25.0, "task_hurryup", TASK_HURRYUP)
    send_event("bombplanted")
}

public task_hurryup()
{
    if (g_enabled && !g_bombDefused)
        send_event("hurryup")
}

public on_bomb_defused()
{
    if (!g_enabled)
        return

    remove_task(TASK_HURRYUP)
    g_bombDefused = true
    send_event("bombdefused")
}

public on_bomb_exploded()
{
    if (!g_enabled)
        return

    remove_task(TASK_HURRYUP)
    g_bombExploded = true
    send_event("bombexploded")
}

public on_hostage_touched()
{
    if (!g_enabled || g_hostageTouched)
        return

    g_hostageTouched = true
    send_event("hostagefollow")
}

public on_hostage_hurt()
{
    return g_enabled ? HAM_SUPERCEDE : HAM_IGNORED
}

public on_hostages_rescued()
{
    send_event("hostagesrescued")
}

public grenade_throw(id, grenade, weapon)
{
    if (g_enabled && weapon == CSW_FLASHBANG)
        client_print(0, print_chat, "%n: TIM FLAAAASH", id)
}

public on_flashbang_idle(weapon)
{
    if (g_setting[SET_FLASH] && !g_flashThrown) {
        g_flashThrown = true
        client_cmd(0, "-attack")
    }
}

public on_screenfade(id)
{
    if (!g_flashProtectionActive)
        return

    message_begin(MSG_ONE, g_msgScreenFade, _, id)
    write_short(3<<12) // duration
    write_short(1<<6) // hold time
    write_short(0) // flags
    write_byte(random(255)) // r
    write_byte(random(255)) // g
    write_byte(random(255)) // b
    write_byte(235) // a
    message_end()
}

public on_zoompistol_attack(weapon)
{
    if (!g_setting[SET_ANTIZOOMPISTOL])
        return HAM_IGNORED

    new owner = pev(weapon, pev_owner)
    new params[1]
    params[0] = cs_get_weapon_id(weapon) != CSW_AWP
    client_print(0, print_chat, "%n bruger %szoompistol!1!!", owner, params[0] ? "(mild) " : "")
    set_task(0.1, "task_zoomslap", TASK_ZOOMSLAP + owner, params, sizeof params)

    return HAM_IGNORED
}

public task_zoomslap(const params[], taskid)
{
    new id = taskid - TASK_ZOOMSLAP
    if (is_user_alive(id))
        user_slap(id, params[0] ? random_num(10, 45) : random_num(17, 85))
}

// ----------------------------------------------------------------------------
// Team balancing
// ----------------------------------------------------------------------------

request_balance(games)
{
    new JSON:args = json_init_object()
    json_object_set_number(args, "games", games)
    send_command("balance", args)
    json_free(args)

    g_awaitingBalance = true
    remove_task(TASK_BALANCE_TIMEOUT)
    set_task(3.5, "task_balance_timeout", TASK_BALANCE_TIMEOUT)
    expect_reply()
}

request_player_stats()
{
    send_event_always("playerstats")
    g_awaitingStats = true
    remove_task(TASK_STATS_TIMEOUT)
    set_task(3.0, "task_stats_timeout", TASK_STATS_TIMEOUT)
    expect_reply()
}

// Replies arrive on the same UDP socket; poll it while one is expected
expect_reply()
{
    if (!task_exists(TASK_REPLY_POLL))
        set_task(0.1, "task_reply_poll", TASK_REPLY_POLL, _, _, "b")
}

public task_reply_poll()
{
    static buf[4096]
    while (g_socket && socket_is_readable(g_socket, 0)) {
        if (socket_recv(g_socket, buf, charsmax(buf)) <= 0)
            break
        handle_reply(buf)
    }

    if (!g_awaitingBalance && !g_awaitingStats)
        remove_task(TASK_REPLY_POLL)
}

public task_balance_timeout()
{
    g_awaitingBalance = false
    log_amx("Balance: no reply from the web app at %s:%d", g_serverHost, g_serverPort)
}

public task_stats_timeout()
{
    g_awaitingStats = false
    arrayset(g_hasStats, false, sizeof g_hasStats)
    if (!g_warnedNoStats)
        log_amx("Noob buff: no player stats from the web app at %s:%d, no buffs until it replies", g_serverHost, g_serverPort)
    g_warnedNoStats = true
}

// Balance replies are an array of { steamid, team },
// player stats { cmd: "playerstats", args: [ { id, sips, kills, deaths } ] }
handle_reply(const data[])
{
    new JSON:reply = json_parse(data)
    if (reply == Invalid_JSON) {
        log_amx("Could not read a reply from the web app")
        return
    }

    new cmd[32]
    if (json_is_array(reply) && g_awaitingBalance) {
        g_awaitingBalance = false
        remove_task(TASK_BALANCE_TIMEOUT)
        apply_balance(reply)
    } else if (json_is_object(reply) && json_object_get_string(reply, "cmd", cmd, charsmax(cmd)) && equal(cmd, "playerstats")) {
        g_awaitingStats = false
        g_warnedNoStats = false
        remove_task(TASK_STATS_TIMEOUT)
        apply_player_stats(reply)
    }
    json_free(reply)
}

apply_player_stats(JSON:reply)
{
    arrayset(g_hasStats, false, sizeof g_hasStats)

    new JSON:list = json_object_get_value(reply, "args")
    new playerId[MAX_AUTHID_LENGTH]
    for (new i, count = json_array_get_count(list); i < count; i++) {
        new JSON:entry = json_array_get_value(list, i)
        json_object_get_string(entry, "id", playerId, charsmax(playerId))
        new id = find_player_by_id(playerId)
        if (id) {
            g_hasStats[id] = true
            g_statSips[id] = json_object_get_number(entry, "sips")
            g_statKills[id] = json_object_get_number(entry, "kills")
            g_statDeaths[id] = json_object_get_number(entry, "deaths")
        }
        json_free(entry)
    }
    json_free(list)

    send_sips_to_scoreboards()
}

// ----------------------------------------------------------------------------
// Scoreboard sips: the scoreboard's Money column shows each player's sips instead
// (the HP column is blank for dead players). The game sends Account per viewer
// (with -1 to hide enemies); every one is rewritten, and new sips are pushed when
// the web app sends them.
// ----------------------------------------------------------------------------

public on_account(msgid, dest, receiver)
{
    if (!g_enabled || !g_setting[SET_SIPS])
        return PLUGIN_CONTINUE

    new player = get_msg_arg_int(1)
    if (1 <= player <= MAX_PLAYERS && g_hasStats[player])
        set_msg_arg_int(2, ARG_LONG, g_statSips[player])
    return PLUGIN_CONTINUE
}

send_sips_to_scoreboards()
{
    if (!g_msgAccount || !g_enabled || !g_setting[SET_SIPS])
        return

    new viewers[MAX_PLAYERS], num
    get_players(viewers, num, "ch")
    for (new i; i < num; i++) {
        for (new player = 1; player <= MAX_PLAYERS; player++) {
            if (!g_hasStats[player] || !is_user_connected(player))
                continue
            message_begin(MSG_ONE, g_msgAccount, _, viewers[i])
            write_byte(player)
            write_long(g_statSips[player])
            message_end()
        }
    }
}

apply_balance(JSON:response)
{
    new playerId[MAX_AUTHID_LENGTH], team[8], moves[512]
    for (new i, count = json_array_get_count(response); i < count; i++) {
        new JSON:entry = json_array_get_value(response, i)
        json_object_get_string(entry, "steamid", playerId, charsmax(playerId))
        json_object_get_string(entry, "team", team, charsmax(team))
        json_free(entry)

        new id = find_player_by_id(playerId)
        if (!id)
            continue

        new CsTeams:newTeam = equali(team, "CT") ? CS_TEAM_CT : CS_TEAM_T
        if (cs_get_user_team(id) != newTeam) {
            add_move(moves, charsmax(moves), id, team)
            cs_set_user_team(id, newTeam)
        }
    }

    log_amx("Balance: %s", moves[0] ? moves : "teams unchanged")
}

shuffle_players()
{
    new players[MAX_PLAYERS], num
    get_game_players(players, num, "a")

    // Fisher-Yates
    for (new i = num - 1; i > 0; i--) {
        new j = random_num(0, i)
        new tmp = players[i]
        players[i] = players[j]
        players[j] = tmp
    }

    new moves[512]
    for (new i; i < num; i++) {
        new CsTeams:team = i % 2 ? CS_TEAM_T : CS_TEAM_CT
        add_move(moves, charsmax(moves), players[i], team == CS_TEAM_T ? "T" : "CT")
        cs_set_user_team(players[i], team)
    }
    log_amx("Shuffle: %s", moves)
}

// ----------------------------------------------------------------------------
// Web server communication
//
// Everything is sent as newline-terminated JSON over a single UDP socket,
// so a slow or dead web server never blocks the game.
// ----------------------------------------------------------------------------

public on_server_address_changed()
{
    if (g_socket) {
        socket_close(g_socket)
        g_socket = 0
    }
    g_socketRetryAt = 0.0
}

bool:ensure_socket()
{
    if (g_socket)
        return true

    // Opening resolves the hostname, which blocks. Don't retry on every event.
    if (get_gametime() < g_socketRetryAt)
        return false

    new error
    g_socket = socket_open(g_serverHost, g_serverPort, SOCKET_UDP, error)
    if (error) {
        log_amx("Could not open socket to %s:%d (error %d)", g_serverHost, g_serverPort, error)
        g_socket = 0
        g_socketRetryAt = get_gametime() + SOCKET_RETRY_DELAY
        return false
    }
    return true
}

send_raw(const data[])
{
    if (!ensure_socket())
        return

    static buf[4096]
    new len = formatex(buf, charsmax(buf), "%s\n", data)
    socket_send(g_socket, buf, len)
}

send_json(JSON:value)
{
    static buf[4000]
    json_serial_to_string(value, buf, charsmax(buf))
    send_raw(buf)
}

send_command(const cmd[], JSON:args)
{
    new JSON:msg = json_init_object()
    json_object_set_string(msg, "cmd", cmd)
    json_object_set_value(msg, "args", args)
    send_json(msg)
    json_free(msg)
}

JSON:player_json(id, const team[] = "")
{
    new name[MAX_NAME_LENGTH], playerId[MAX_AUTHID_LENGTH], currentTeam[16]
    get_user_name(id, name, charsmax(name))
    get_player_id(id, playerId, charsmax(playerId))
    if (team[0])
        copy(currentTeam, charsmax(currentTeam), team)
    else
        get_user_team(id, currentTeam, charsmax(currentTeam))

    new JSON:obj = json_init_object()
    json_object_set_string(obj, "id", playerId)
    json_object_set_string(obj, "name", name)
    json_object_set_string(obj, "team", currentTeam)
    return obj
}

send_player_cmd(const cmd[], id, const team[] = "")
{
    new JSON:player = player_json(id, team)
    send_command(cmd, player)
    json_free(player)
}

send_players()
{
    new JSON:list = json_init_array()
    new players[MAX_PLAYERS], num
    get_game_players(players, num)
    for (new i; i < num; i++) {
        new JSON:player = player_json(players[i])
        json_array_append_value(list, player)
        json_free(player)
    }
    send_command("playersync", list)
    json_free(list)
}

send_event(const cmd[], const arg1[] = "", const arg2[] = "", const sound[] = "", const weapon[] = "", bool:headshot = false)
{
    if (g_enabled)
        send_event_always(cmd, arg1, arg2, sound, weapon, headshot)
}

// `sound` overrides which media folder the web server plays from (defaults to cmd).
// Kill events also carry the weapon and headshot flag, for the web app's killfeed.
send_event_always(const cmd[], const arg1[] = "", const arg2[] = "", const sound[] = "", const weapon[] = "", bool:headshot = false)
{
    new JSON:event = json_init_object()
    json_object_set_string(event, "cmd", cmd)

    if (arg1[0]) {
        new JSON:args = json_init_array()
        json_array_append_string(args, arg1)
        if (arg2[0])
            json_array_append_string(args, arg2)
        json_object_set_value(event, "args", args)
        json_free(args)
    }

    if (sound[0] && !equal(sound, cmd))
        json_object_set_string(event, "sound", sound)
    if (weapon[0])
        json_object_set_string(event, "weapon", weapon)
    if (headshot)
        json_object_set_bool(event, "headshot", true)

    send_json(event)
    json_free(event)
}

// ----------------------------------------------------------------------------
// Commands
// ----------------------------------------------------------------------------

public cmd_toggle_setting(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1))
        return PLUGIN_HANDLED

    new cmd[32]
    read_argv(0, cmd, charsmax(cmd))

    for (new Setting:s; s < Setting; s++) {
        if (!equali(cmd, SETTING_CMD[s]))
            continue

        g_setting[s] = read_argc() > 1 ? read_argv_int(1) != 0 : !g_setting[s]
        log_admin(id, "turned %s %s", SETTING_NAME[s], g_setting[s] ? "on" : "off")

        if (SETTING_ANNOUNCE[s])
            client_print(0, print_chat, "Nobel Beer CS %s %s", SETTING_NAME[s], g_setting[s] ? "enabled" : "disabled")
        else
            console_print(id, "Nobel Beer CS %s %s", SETTING_NAME[s], g_setting[s] ? "enabled" : "disabled")
        break
    }
    return PLUGIN_HANDLED
}

public cmd_round_mode(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1) || !g_enabled)
        return PLUGIN_HANDLED

    new cmd[32]
    read_argv(0, cmd, charsmax(cmd))

    new RoundMode:mode = MODE_NORMAL
    for (new RoundMode:m = MODE_KNIFE; m < RoundMode; m++) {
        if (equali(cmd, MODE_CMD[m]))
            mode = m
    }

    if (g_mode == MODE_NORMAL && g_nextMode == MODE_NORMAL) {
        g_nextMode = mode
        g_endModeAfterRound = false
        log_admin(id, "queued a %s for next round", MODE_NAME[mode])
        announce_mode_queued(mode)
        client_print(0, print_chat, "Nobel %s enabled!", MODE_NAME[mode])
    } else if (g_mode == mode || g_nextMode == mode) {
        g_endModeAfterRound = true
        log_admin(id, "made this the last %s", MODE_NAME[mode])
        announce_mode_last(mode)
    } else {
        console_print(id, "Another special round is already active.")
    }
    return PLUGIN_HANDLED
}

public cmd_nobel_end_mode_now(id, level, cid)
{
    if (cmd_access(id, level, cid, 1) && g_enabled && (g_mode != MODE_NORMAL || g_nextMode != MODE_NORMAL)) {
        log_admin(id, "ended the %s now", MODE_NAME[g_mode != MODE_NORMAL ? g_mode : g_nextMode])
        end_round_mode()
    }
    return PLUGIN_HANDLED
}

public cmd_nobel(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1))
        return PLUGIN_HANDLED

    console_print(id, "Nobel Beer CS %s (state %s, round %d)", g_enabled ? "enabled" : "disabled", STATE_NAME[g_state], g_roundCount)
    for (new Setting:s; s < Setting; s++)
        console_print(id, "  %s: %s", SETTING_CMD[s], g_setting[s] ? "on" : "off")
    console_print(id, "  special round: %s", g_mode == MODE_NORMAL ? "none" : MODE_NAME[g_mode])
    if (g_nextMode != MODE_NORMAL)
        console_print(id, "  next round: %s", MODE_NAME[g_nextMode])
    return PLUGIN_HANDLED
}

public cmd_nobel_maps(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1))
        return PLUGIN_HANDLED

    new file[64]
    new dir = open_dir("maps", file, charsmax(file))
    if (!dir) {
        console_print(id, "No maps found on server")
        return PLUGIN_HANDLED
    }

    new count
    do {
        new len = strlen(file)
        if (len > 4 && equali(file[len - 4], ".bsp")) {
            file[len - 4] = 0
            console_print(id, "%d: %s", ++count, file)
        }
    } while (next_file(dir, file, charsmax(file)))
    close_dir(dir)

    return PLUGIN_HANDLED
}

public cmd_nobel_theme(id, level, cid)
{
    if (!cmd_access(id, level, cid, 2))
        return PLUGIN_HANDLED

    new theme[32]
    read_argv(1, theme, charsmax(theme))
    log_admin(id, "changed the sound theme to %s", theme)
    client_print(0, print_chat, "Nobel sound theme changed to: %s!", theme)
    send_event("theme", theme)
    return PLUGIN_HANDLED
}

public cmd_nobel_balance(id, level, cid)
{
    if (!cmd_access(id, level, cid, 2))
        return PLUGIN_HANDLED

    new games = read_argv_int(1)
    log_admin(id, "balanced the teams (last %d games per player)", games)
    request_balance(games)
    return PLUGIN_HANDLED
}

public cmd_nobel_shuffle(id, level, cid)
{
    if (cmd_access(id, level, cid, 1) && g_enabled) {
        log_admin(id, "shuffled the teams")
        shuffle_players()
    }
    return PLUGIN_HANDLED
}

public cmd_nobel_sendplayers(id, level, cid)
{
    if (cmd_access(id, level, cid, 1))
        send_players()
    return PLUGIN_HANDLED
}

public cmd_badum(id, level, cid)
{
    if (cmd_access(id, level, cid, 1) && g_setting[SET_BADUM]) {
        log_admin(id, "played badum")
        send_event("badum")
    }
    return PLUGIN_HANDLED
}

public cmd_ready(id, level, cid)
{
    if (cmd_access(id, level, cid, 1) && !g_enabled) {
        log_admin(id, "played ready")
        send_event_always("ready")
    }
    return PLUGIN_HANDLED
}

public cmd_shutup(id, level, cid)
{
    if (cmd_access(id, level, cid, 1)) {
        log_admin(id, "played shutup")
        send_event_always("shutup")
    }
    return PLUGIN_HANDLED
}

public cmd_nobel_start(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1) || g_state != STATE_STOPPED)
        return PLUGIN_HANDLED

    log_admin(id, "started Nobel Beer CS (nobel_map_%s.cfg)", g_mapType)
    g_roundCount = 0
    set_state(STATE_STARTING)
    send_players()
    request_balance(50)

    // server.cfg first, so the map type config can override it (e.g. mp_roundtime)
    server_cmd("exec server.cfg")
    server_cmd("exec nobel_map_%s.cfg", g_mapType)
    server_cmd("exec mr15.cfg")

    set_task(1.0, "task_periodic", TASK_PERIODIC, _, _, "b")
    return PLUGIN_HANDLED
}

public cmd_nobel_serverstart(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1) || g_enabled)
        return PLUGIN_HANDLED

    log_admin(id, "went live")
    g_enabled = true
    g_setting[SET_PAUSE] = true
    g_setting[SET_KNIFEPAUSE] = true
    g_setting[SET_ANTIZOOMPISTOL] = true
    g_setting[SET_FLASHPROTECTION] = false
    arrayset(g_roundsWithoutKill, 0, sizeof g_roundsWithoutKill)
    arrayset(g_killedThisRound, false, sizeof g_killedThisRound)
    arrayset(g_hasStats, false, sizeof g_hasStats)

    start_new_round()
    set_state(STATE_STARTED)

    return PLUGIN_HANDLED
}

public cmd_nobel_stop(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1) || g_state != STATE_STARTED)
        return PLUGIN_HANDLED

    log_admin(id, "stopped Nobel Beer CS")
    end_round_mode()
    g_enabled = false
    remove_task(TASK_PERIODIC)
    server_cmd("exec stop.cfg")
    client_print(0, print_console, "Nobel Beer CS disabled!")
    set_state(STATE_STOPPED)
    return PLUGIN_HANDLED
}
