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
#define TELESWAP_EARLIEST 10.0

// Noob buff: free gear after this many rounds in a row without a kill (additive),
// for players in the lower half by sips with fewer kills than deaths
#define NOOBBUFF_VEST_ROUNDS 2
#define NOOBBUFF_HELMET_ROUNDS 3
#define NOOBBUFF_GRENADES_ROUNDS 4
#define NOOBBUFF_FULL_ROUNDS 5

// Mario Kart round: a race to the other team's spawn. Each player to get there
// scores a point for their team, and the first team to KART_POINTS wins.
#define KART_TICK 0.1
#define KART_POINTS 10
// sv_maxspeed during the round, so mushrooms and stars can go faster than usual
// (the client itself caps forward speed at 400)
#define KART_SPEED_LIMIT 450
// mp_roundtime during the round (minutes)
#define KART_ROUND_TIME 3.0
// How long the win sound (mk_win) plays before the game pauses for the losers to
// drink, with mk_finished playing
#define KART_WIN_SOUND_TIME 7.0
// A tie when time runs out: the round goes on this long, and the next point wins
#define KART_SUDDEN_DEATH_TIME 60
#define KART_KILL_MONEY 350
#define KART_SHELL_HIT_MONEY 300
#define KART_FIREBALL_HIT_MONEY 50
#define KART_BOBOMB_HIT_MONEY 100
// Bob-omb: thrown forward, and every player this close is stunned when it goes off
#define KART_BOBOMB_SPEED 450.0
#define KART_BOBOMB_LIFT 300.0
#define KART_BOBOMB_FUSE 3.0
#define KART_BOBOMB_RADIUS 200.0
// Fire flower: 5 fireballs, bouncing like green shells but shorter lived. A hit
// hurts like a knife slash and slows the player down a little.
#define KART_FIREBALLS 5
#define KART_FIREBALL_SPEED 960.0
#define KART_FIREBALL_LIFETIME 1.5
#define KART_FIREBALL_DAMAGE 15
#define KART_FIREBALL_SLOW_SPEED 200.0
#define KART_FIREBALL_SLOW_TIME 1.5
// Item boxes are put out this far apart until the map is covered, so big maps get
// more of them (up to KART_BOXES)
#define KART_BOXES 48
#define KART_BOX_SPACING 400.0
#define KART_BOX_RESPAWN 10.0
#define KART_SPIN_TIME 1.5
#define KART_STUN_TIME 3.0
#define KART_BOOST_SPEED 400.0
#define KART_STAR_TIME 5.0
// A short boost when the race starts, and when moving again after being sent back,
// for players holding forward right then
#define KART_START_BOOST_TIME 1.5
#define KART_BLUESHELL_DELAY 2.5
// It rises and spins above the thrower for this long, then darts to its target
#define KART_BLUESHELL_RISE 1.0
#define KART_SHELL_SPEED 700.0
#define KART_SHELL_LIFETIME 6.0
// Item box spots: where players have stood on the map, at least this far apart
#define SPOT_SPACING 128.0
#define MAX_SPOTS 512
#define SPOTS_DIR "nobel_spots"

const PRIMARY_WEAPONS = (1<<CSW_SCOUT) | (1<<CSW_XM1014) | (1<<CSW_MAC10) | (1<<CSW_AUG) | (1<<CSW_UMP45)
    | (1<<CSW_SG550) | (1<<CSW_GALIL) | (1<<CSW_FAMAS) | (1<<CSW_AWP) | (1<<CSW_MP5NAVY) | (1<<CSW_M249)
    | (1<<CSW_M3) | (1<<CSW_M4A1) | (1<<CSW_TMP) | (1<<CSW_G3SG1) | (1<<CSW_SG552) | (1<<CSW_AK47) | (1<<CSW_P90)

// Task IDs. Per-player tasks add the player id (1-32) to their base.
enum (+= 100)
{
    TASK_UNFREEZE = 100,
    TASK_RAMBO,
    TASK_ZOOMSLAP,
    TASK_RAMBO_SLAP,
    TASK_RAMBO_C4,
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
    TASK_PAUSE_ACK,
    TASK_KART,
    TASK_KART_COUNTDOWN,
    TASK_KART_STRIP,
    TASK_KART_TIME_UP,
    TASK_KART_FINISHED,
    TASK_KART_BLUESHELL,
    TASK_SPOTS
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
    MODE_BONG,
    MODE_KART
}
new const MODE_CMD[RoundMode][] = { "", "nobel_knife", "nobel_rambo", "nobel_bong", "nobel_kart" }
new const MODE_NAME[RoundMode][] = { "", "LAAAARJF ROUND", "RAMBO ROUND", "BONG ROUND", "MARIO KART ROUND" }
new const MODE_EVENT[RoundMode][] = { "", "leif", "rambo", "bongintro", "mariokart" }

// Mario Kart items, one held at a time
enum KartItem
{
    ITEM_NONE,
    ITEM_MUSHROOM,
    ITEM_BANANA,
    ITEM_GREENSHELL,
    ITEM_STAR,
    ITEM_LIGHTNING,
    ITEM_BLUESHELL,
    ITEM_BOBOMB,
    ITEM_FIREFLOWER
}
new const ITEM_NAME[KartItem][] = { "", "MUSHROOM", "BANANA", "GREEN SHELL", "STAR", "LIGHTNING", "BLUE SHELL", "BOB-OMB", "FIRE FLOWER" }
// The web app event (and media folder) for using each item
new const ITEM_EVENT[KartItem][] = { "", "mk_mushroom", "mk_banana", "mk_greenshell", "mk_star", "mk_lightning", "mk_blueshell", "mk_bobomb", "mk_fireflower" }
// Odds of each item (in percent), and slightly better ones for the team behind on
// points. Green shells are the most common (they're the funniest), lightning and
// blue shells are rare.
new const ITEM_ODDS[2][KartItem] = {
    { 0, 18, 18, 32, 8, 2, 3, 9, 10 },
    { 0, 17, 12, 30, 12, 4, 5, 10, 10 }
}
new const RAINBOW[][3] = { { 255, 0, 0 }, { 255, 128, 0 }, { 255, 255, 0 }, { 0, 255, 0 }, { 0, 128, 255 }, { 160, 0, 255 } }
new const KART_CLASSES[][] = { "nobel_itembox", "nobel_banana", "nobel_shell", "nobel_blueshell", "nobel_bobomb", "nobel_fireball" }
// The item box is Half-Life's weapon box (in valve/, which every client has)
new const ITEMBOX_MODEL[] = "models/w_weaponbox.mdl"
new const ITEMBOX_FALLBACK_MODEL[] = "models/w_kevlar.mdl"
new const BANANA_MODEL[] = "models/w_flashbang.mdl"
new const SHELL_MODEL[] = "models/w_hegrenade.mdl"
new const BOBOMB_MODEL[] = "models/w_smokegrenade.mdl"
// Half-Life's fireball (in valve/)
new const FIREBALL_SPRITE[] = "sprites/xfireball3.spr"

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
new bool:g_announceUnfreeze[MAX_PLAYERS + 1]
new bool:g_boostOnUnfreeze[MAX_PLAYERS + 1]
// Rambo: we sent this player +attack; and when we may send it again
new bool:g_forcedAttack[MAX_PLAYERS + 1]
new Float:g_nextForcedAttack[MAX_PLAYERS + 1]
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
new g_lastTeam[MAX_PLAYERS + 1][16]

new g_mapName[32]
new g_mapType[8]
new g_msgScreenFade
new g_pauseMenu
// At the end of a Mario Kart race: 9 ends Mario Kart, 0 races on
new g_kartPauseMenu
new bool:g_kartEndPause
new g_vault = INVALID_HANDLE
new g_socket
new Float:g_socketRetryAt
new Trie:g_overrides
new Array:g_botIds
new g_botIdIndex[MAX_PLAYERS + 1] = { -1, ... }

// Mario Kart round
new bool:g_raceStarted
new bool:g_raceOver
new bool:g_finalLap
new bool:g_suddenDeath
new g_points[CsTeams]
new g_kartTicks
new g_oldMaxSpeed = -1
new Float:g_oldRoundTime = -1.0
// The team that won the race, while the losers drink (before they're slain)
new CsTeams:g_raceWinner
// Each team's finish line: the middle of where the other team spawned
new Float:g_finish[CsTeams][3]
new Float:g_finishRadius[CsTeams]
new bool:g_hasFinish[CsTeams]
new Float:g_spawnOrigin[MAX_PLAYERS + 1][3]
new Float:g_spawnAngles[MAX_PLAYERS + 1][3]
// Distance from the player's spawn to their finish line
new Float:g_raceLength[MAX_PLAYERS + 1]
new KartItem:g_item[MAX_PLAYERS + 1]
new bool:g_useHeld[MAX_PLAYERS + 1]
new Float:g_botUseAt[MAX_PLAYERS + 1]
new Float:g_boostUntil[MAX_PLAYERS + 1]
new Float:g_starUntil[MAX_PLAYERS + 1]
new Float:g_slowUntil[MAX_PLAYERS + 1]
new Float:g_slowSpeed[MAX_PLAYERS + 1]
// Shots left of a fire flower
new g_itemUses[MAX_PLAYERS + 1]
new Float:g_trailUntil[MAX_PLAYERS + 1]
// The max speed an item gives the player (0: the weapon's own)
new Float:g_kartSpeed[MAX_PLAYERS + 1]
new Float:g_nextSendBack[MAX_PLAYERS + 1]
// Spinning out: when it started (0: not spinning) and the view's yaw then
new Float:g_spinStart[MAX_PLAYERS + 1]
new Float:g_spinYaw[MAX_PLAYERS + 1]
new Float:g_spinTime[MAX_PLAYERS + 1]
new Float:g_spinTurn[MAX_PLAYERS + 1]
// Who fired the blue shell on its way to this player
new g_blueShellFrom[MAX_PLAYERS + 1]
new Array:g_spots
new bool:g_spotsChanged
new g_hudSync
new g_scoreSync
new g_itemboxModel[64]
new g_sprBeam
new g_sprLightning
new g_sprRing
new g_sprExplosion
new g_msgScoreInfo

// Cvars
new g_serverHost[64]
new g_serverPort
new g_numShield
new g_numWeed
new g_numKit
new g_includeBots

public plugin_precache()
{
    // Stock game files, so nobody has to download anything
    copy(g_itemboxModel, charsmax(g_itemboxModel), file_exists(ITEMBOX_MODEL, true) ? ITEMBOX_MODEL : ITEMBOX_FALLBACK_MODEL)
    precache_model(g_itemboxModel)
    precache_model(BANANA_MODEL)
    precache_model(SHELL_MODEL)
    precache_model(BOBOMB_MODEL)
    precache_model(FIREBALL_SPRITE)
    g_sprBeam = precache_model("sprites/laserbeam.spr")
    g_sprLightning = precache_model("sprites/lgtning.spr")
    g_sprRing = precache_model("sprites/shockwave.spr")
    g_sprExplosion = precache_model("sprites/zerogxplode.spr")
}

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR)

    register_event("HLTV", "on_new_round", "a", "1=0", "2=0")
    register_event("DeathMsg", "on_death", "a")
    register_event("30", "on_intermission", "a")
    register_event("TeamInfo", "on_team_info", "a")
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
    register_forward(FM_CmdStart, "on_cmd_start")
    // The newer CS 1.6 scoreboard's Money column; only sent by updated game servers
    g_msgAccount = get_user_msgid("Account")
    if (g_msgAccount)
        register_message(g_msgAccount, "on_account")
    RegisterHam(Ham_CS_Player_ResetMaxSpeed, "player", "on_reset_maxspeed", 1)
    RegisterHam(Ham_Weapon_WeaponIdle, "weapon_flashbang", "on_flashbang_idle")
    RegisterHam(Ham_Item_Deploy, "weapon_hegrenade", "on_hegrenade_deploy", 1)
    RegisterHam(Ham_TraceAttack, "hostage_entity", "on_hostage_hurt")
    RegisterHam(Ham_TakeDamage, "hostage_entity", "on_hostage_hurt")
    RegisterHam(Ham_TakeDamage, "player", "on_player_take_damage")
    RegisterHam(Ham_Use, "hostage_entity", "on_hostage_use")
    RegisterHam(Ham_Touch, "armoury_entity", "on_weapon_touch")
    RegisterHam(Ham_Touch, "weaponbox", "on_weapon_touch")
    register_forward(FM_PlayerPreThink, "on_player_prethink")
    register_touch("nobel_itembox", "player", "on_itembox_touch")
    register_touch("nobel_banana", "player", "on_banana_touch")
    register_touch("nobel_shell", "player", "on_shell_touch")
    register_touch("nobel_bobomb", "player", "on_bobomb_touch")
    register_touch("nobel_fireball", "player", "on_fireball_touch")
    RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_awp", "on_zoompistol_attack")
    RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_g3sg1", "on_zoompistol_attack")
    RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_sg550", "on_zoompistol_attack")

    // Slap people shooting anything but the M249 in rambo rounds.
    // The slap comes after the shot: see on_rambo_attack.
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
    register_concmd("nobel_teleswapnow", "cmd_nobel_teleswapnow", ACCESS_ADMIN, "[player] [player] - Teleswap now: two named players, or a random T and CT.")
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
    load_spots()
    set_task(2.0, "task_record_spots", TASK_SPOTS, _, _, "b")
    g_hudSync = CreateHudSyncObj()
    g_scoreSync = CreateHudSyncObj()

    g_msgScreenFade = get_user_msgid("ScreenFade")
    g_msgScoreInfo = get_user_msgid("ScoreInfo")
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
    restore_kart_cvars()
    save_spots()
    ArrayDestroy(g_spots)
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
    remove_task(TASK_KART_BLUESHELL + id)
    g_spinStart[id] = 0.0
    g_item[id] = ITEM_NONE
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
    // Where knifed players go back to in the Mario Kart round
    pev(id, pev_origin, g_spawnOrigin[id])
    pev(id, pev_v_angle, g_spawnAngles[id])

    if (!g_enabled)
        return

    if (g_setting[SET_FLASH]) {
        give_item(id, "weapon_flashbang")
        give_item(id, "weapon_flashbang")
    }

    if (g_mode == MODE_RAMBO) {
        set_user_health(id, 200)
        give_item(id, "item_assaultsuit")
        give_rambo_weapons(id)
        set_task(5.0, "task_rambo", TASK_RAMBO + id, _, _, "b")
    }

    if (g_mode == MODE_KART) {
        strip_user_weapons(id)
        give_item(id, "weapon_knife")
        reset_kart_player(id)
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
    if (!is_user_alive(id))
        return

    if (g_frozen[id])
        set_user_maxspeed(id, FROZEN_SPEED)
    else if (g_mode == MODE_KART && g_kartSpeed[id] > 0.0)
        set_user_maxspeed(id, g_kartSpeed[id])
}

freeze_player(id, Float:duration = FREEZE_TIME, bool:announce = true)
{
    if (!is_user_alive(id))
        return

    g_frozen[id] = true
    g_announceUnfreeze[id] = announce
    g_boostOnUnfreeze[id] = false
    ExecuteHamB(Ham_CS_Player_ResetMaxSpeed, id)

    remove_task(TASK_UNFREEZE + id)
    set_task(duration, "task_unfreeze", TASK_UNFREEZE + id)
}

public task_unfreeze(taskid)
{
    new id = taskid - TASK_UNFREEZE
    g_frozen[id] = false

    if (is_user_alive(id)) {
        ExecuteHamB(Ham_CS_Player_ResetMaxSpeed, id)
        if (g_announceUnfreeze[id])
            client_print(id, print_chat, "You can now move again.")
        if (g_boostOnUnfreeze[id] && g_mode == MODE_KART && g_raceStarted && !g_raceOver)
            start_boost(id)
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
        g_forcedAttack[id] = false
        g_frozen[id] = false
        remove_task(TASK_UNFREEZE + id)
        remove_task(TASK_RAMBO + id)
    }
    client_cmd(0, "-attack")
    reset_kart()
    remove_task(TASK_RAMBO_C4)

    if (g_endModeAfterRound) {
        end_round_mode()
    } else if (g_nextMode != MODE_NORMAL) {
        g_mode = g_nextMode
        g_nextMode = MODE_NORMAL
    }

    if (g_mode == MODE_KART) {
        set_kart_cvars()
        // After the round restart has handed out the C4
        set_task(0.1, "task_kart_strip", TASK_KART_STRIP)
        // The countdown ends as freeze time does
        new Float:delay = get_cvar_float("mp_freezetime") - 3.0
        set_task(delay > 0.1 ? delay : 0.1, "task_kart_countdown", TASK_KART_COUNTDOWN)
    }

    // No bomb in the rambo round: take it off whoever the round restart handed it to
    if (g_mode == MODE_RAMBO)
        set_task(0.1, "task_rambo_remove_c4", TASK_RAMBO_C4)

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
    // Everyone drinks the fællesskål at the start of the round (the web app counts it)
    refresh_player_stats_soon()

    set_task(10.0, "task_money_check", TASK_MONEY_CHECK)
}

public on_round_start()
{
    send_players()

    if (!g_enabled)
        return

    send_event("roundstart")
    g_bombDefused = false
    g_bombExploded = false
    g_timeElapsed = false

    if (equali(g_mapName, "de_rats"))
        send_event("rats")

    if (g_mode == MODE_KART)
        start_race()

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
// Teleswap: a random living T and CT swap places, with a short yellow flash
// ----------------------------------------------------------------------------

public task_teleswap()
{
    if (g_enabled && g_setting[SET_TELESWAP] && !g_paused)
        random_teleswap()
}

// Swaps a random living T and CT. Returns false if a team has nobody alive.
bool:random_teleswap()
{
    new ts[MAX_PLAYERS], cts[MAX_PLAYERS], numT, numCT
    get_game_players(ts, numT, "ae", "TERRORIST")
    get_game_players(cts, numCT, "ae", "CT")
    if (!numT || !numCT)
        return false

    teleswap_players(ts[random(numT)], cts[random(numCT)])
    return true
}

teleswap_players(first, second)
{
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

// Bright yellow screen fading out over one second, like a short flashbang
flash_fade(id)
{
    message_begin(MSG_ONE, g_msgScreenFade, _, id)
    write_short(1<<12) // duration: 1 second
    write_short(0) // hold time
    write_short(0x0000) // FFADE_IN: from the color back to normal
    write_byte(255) // r
    write_byte(240) // g
    write_byte(0) // b
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
    save_spots()

    // Before the next round starts, which reads the round time
    if (g_mode == MODE_KART && g_endModeAfterRound)
        restore_kart_cvars()

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

    if (g_mode == MODE_KART)
        swap_kart_teams()

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

    if (g_mode == MODE_KART) {
        reset_kart()
        restore_kart_cvars()
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
        case MODE_KART: {
            csay("green", "NEXT ROUND IS MARIO KART ROUND !!!!!")
            csay("red", "RACE TO THE ENEMY SPAWN !!!!")
            csay("blue", "Item boxes: run over them, fire with E or F")
            csay("red", "FAT DET !!!")
        }
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
        case MODE_KART: {
            csay("green", "!! MARIO KART RUNDE !!")
            csay("red", "RACE TO THE ENEMY SPAWN: FIRST TEAM TO 10 WINS")
            csay("blue", "Item boxes: run over them, fire with E or F")
            csay("red", "A knife sends them back to the start!")
        }
    }
    server_exec()
}

give_rambo_weapons(id)
{
    strip_user_weapons(id)
    give_item(id, "weapon_m249")
    give_item(id, "weapon_hegrenade")
    cs_set_user_bpammo(id, CSW_M249, 10000)
}

public task_rambo_remove_c4()
{
    new players[MAX_PLAYERS], num
    get_players(players, num, "a")
    for (new i; i < num; i++) {
        if (user_has_weapon(players[i], CSW_C4))
            give_rambo_weapons(players[i])
    }
}

public task_rambo(taskid)
{
    new id = taskid - TASK_RAMBO
    if (!is_user_alive(id))
        return

    if (!user_has_weapon(id, CSW_HEGRENADE))
        give_item(id, "weapon_hegrenade")

    // Keep the M249 loaded
    new m249 = find_ent_by_owner(-1, "weapon_m249", id)
    if (m249 > 0)
        cs_set_weapon_ammo(m249, 100)
}

// Rambos can't stop firing the M249: the server holds their fire button, which works
// for bots too and can't be undone by tapping the mouse. Humans also get +attack sent
// to their client: the client only draws its own shots (impacts, sounds) when it knows
// it is firing.
public on_cmd_start(id, uc)
{
    if (g_mode == MODE_KART && is_user_alive(id))
        return kart_cmd_start(id, uc)

    if (g_mode != MODE_RAMBO || !is_user_alive(id))
        return FMRES_IGNORED

    new buttons = get_uc(uc, UC_Buttons)
    if (get_user_weapon(id) != CSW_M249) {
        // Let go again when switching away, so the knife doesn't stab forever
        if (g_forcedAttack[id]) {
            g_forcedAttack[id] = false
            client_cmd(id, "-attack")
        }
        return FMRES_IGNORED
    }

    if (!(buttons & IN_ATTACK) && !is_user_bot(id) && get_gametime() >= g_nextForcedAttack[id]) {
        client_cmd(id, "+attack")
        g_forcedAttack[id] = true
        g_nextForcedAttack[id] = get_gametime() + 0.5
    }

    set_uc(uc, UC_Buttons, buttons | IN_ATTACK)
    return FMRES_HANDLED
}

// Rambos throw an HE the moment they draw it: no deploy or pin-pull animation, and no
// way to hide behind it instead of firing. The game throws it on its next idle check,
// then switches back to the M249 when no HE is left.
public on_hegrenade_deploy(grenade)
{
    new id = pev(grenade, pev_owner)
    if (g_mode != MODE_RAMBO || !(1 <= id <= MAX_PLAYERS) || !is_user_alive(id))
        return

    set_ent_data_float(grenade, "CBaseEntity", "m_flStartThrow", get_gametime())
    set_ent_data_float(grenade, "CBaseEntity", "m_flReleaseThrow", get_gametime())
    set_ent_data_float(grenade, "CBasePlayerWeapon", "m_flTimeWeaponIdle", 0.0)
    set_ent_data_float(id, "CBaseMonster", "m_flNextAttack", 0.0)
}

public on_rambo_attack(weapon)
{
    if (g_mode != MODE_RAMBO)
        return

    // Slap after the shot, never during it: a slap can kill, and killing a player
    // inside their weapon's own code crashes the server
    new owner = pev(weapon, pev_owner)
    if (1 <= owner <= MAX_PLAYERS && !task_exists(TASK_RAMBO_SLAP + owner))
        set_task(0.1, "task_rambo_slap", TASK_RAMBO_SLAP + owner)
}

public task_rambo_slap(taskid)
{
    new id = taskid - TASK_RAMBO_SLAP
    if (g_mode == MODE_RAMBO && is_user_alive(id))
        user_slap(id, random_num(40, 60))
}

// ----------------------------------------------------------------------------
// Mario Kart round: a knife-only race to the other team's spawn. Nobody dies:
// a knife sends players back to their own spawn. Item boxes around the map give
// one item at a time, fired with +use or the flashlight key.
// ----------------------------------------------------------------------------

// A higher sv_maxspeed for mushrooms and stars, and a longer round. Set when the
// round is queued, as the game reads the round time before the round starts.
set_kart_cvars()
{
    if (g_oldMaxSpeed != -1)
        return

    g_oldMaxSpeed = get_cvar_num("sv_maxspeed")
    set_cvar_num("sv_maxspeed", KART_SPEED_LIMIT)
    g_oldRoundTime = get_cvar_float("mp_roundtime")
    set_cvar_float("mp_roundtime", KART_ROUND_TIME)
}

restore_kart_cvars()
{
    if (g_oldMaxSpeed == -1)
        return

    set_cvar_num("sv_maxspeed", g_oldMaxSpeed)
    set_cvar_float("mp_roundtime", g_oldRoundTime)
    g_oldMaxSpeed = -1
}

reset_kart()
{
    remove_task(TASK_KART)
    remove_task(TASK_KART_COUNTDOWN)
    remove_task(TASK_KART_STRIP)
    remove_task(TASK_KART_TIME_UP)
    remove_task(TASK_KART_FINISHED)
    g_raceWinner = CS_TEAM_UNASSIGNED
    g_kartEndPause = false
    g_raceStarted = false
    g_raceOver = false
    g_finalLap = false
    g_suddenDeath = false
    g_points[CS_TEAM_T] = 0
    g_points[CS_TEAM_CT] = 0

    for (new i; i < sizeof KART_CLASSES; i++) {
        new ent = -1
        while ((ent = find_ent_by_class(ent, KART_CLASSES[i])))
            remove_entity(ent)
    }

    for (new id = 1; id <= MAX_PLAYERS; id++)
        reset_kart_player(id)
}

reset_kart_player(id)
{
    remove_task(TASK_KART_BLUESHELL + id)
    g_spinStart[id] = 0.0
    g_item[id] = ITEM_NONE
    g_boostUntil[id] = 0.0
    g_starUntil[id] = 0.0
    g_slowUntil[id] = 0.0
    g_itemUses[id] = 0
    g_kartSpeed[id] = 0.0
    g_nextSendBack[id] = 0.0
    g_blueShellFrom[id] = 0

    if (!is_user_connected(id))
        return

    if (g_trailUntil[id] > 0.0)
        kill_trail(id)
    g_trailUntil[id] = 0.0
    set_user_rendering(id)
    ClearSyncHud(id, g_hudSync)
}

public task_kart_countdown()
{
    send_event("mk_countdown")
}

// No buying in the Mario Kart and rambo rounds, however it's tried (menus, commands,
// autobuy)
public CS_OnBuyAttempt(id, item)
{
    switch (g_mode) {
        case MODE_KART: client_print(id, print_center, "No shopping in Mario Kart!")
        case MODE_RAMBO: client_print(id, print_center, "Rambo doesn't go shopping!")
        default: return PLUGIN_CONTINUE
    }
    return PLUGIN_HANDLED
}

public CS_OnBuy(id, item)
{
    return g_mode == MODE_KART || g_mode == MODE_RAMBO ? PLUGIN_HANDLED : PLUGIN_CONTINUE
}

add_money(id, amount)
{
    if (is_user_connected(id))
        cs_set_user_money(id, min(cs_get_user_money(id) + amount, 16000))
}

// Knives only: no C4, grenades or anything left over from the last round
public task_kart_strip()
{
    new players[MAX_PLAYERS], num
    get_players(players, num, "a")
    for (new i; i < num; i++) {
        strip_user_weapons(players[i])
        give_item(players[i], "weapon_knife")
        // Knife damage is counted in full (see on_player_take_damage)
        cs_set_user_armor(players[i], 0, CS_ARMOR_NONE)
    }
}

// ...and no picking up weapons lying around
public on_weapon_touch(weapon, id)
{
    return g_mode == MODE_KART ? HAM_SUPERCEDE : HAM_IGNORED
}

// Freeze time is over: find the finish lines, put out the item boxes and go
start_race()
{
    set_finish(CS_TEAM_T, CS_TEAM_CT, "info_player_start")
    set_finish(CS_TEAM_CT, CS_TEAM_T, "info_player_deathmatch")

    new players[MAX_PLAYERS], num
    get_players(players, num, "a")
    for (new i; i < num; i++) {
        new id = players[i]
        new CsTeams:team = cs_get_user_team(id)
        if (is_racer_team(team) && g_hasFinish[team])
            g_raceLength[id] = floatmax(1.0, get_distance_f(g_spawnOrigin[id], g_finish[team]))
    }

    task_kart_strip()
    place_item_boxes()
    g_raceStarted = true
    g_kartTicks = 0
    set_task(KART_TICK, "task_kart", TASK_KART, _, _, "b")

    new racers[MAX_PLAYERS], count
    get_players(racers, count, "a")
    for (new i; i < count; i++) {
        if (is_racer_team(cs_get_user_team(racers[i])))
            start_boost(racers[i])
    }
    // Early enough for the win sound to play before the round timer runs out
    set_task(get_cvar_float("mp_roundtime") * 60.0 - KART_WIN_SOUND_TIME - 3.0, "task_kart_time_up", TASK_KART_TIME_UP)
    send_event("mk_go")
    show_score()
}

// Half-time: everyone is on the other team now, but still where they were. Each team
// takes over the other's finish line and points, so everyone keeps racing to the
// same place instead of scoring right where they stand.
swap_kart_teams()
{
    new CsTeams:t = CS_TEAM_T, CsTeams:ct = CS_TEAM_CT
    new Float:finish[3]
    copy_vector(g_finish[t], finish)
    copy_vector(g_finish[ct], g_finish[t])
    copy_vector(finish, g_finish[ct])

    new Float:radius = g_finishRadius[t]
    g_finishRadius[t] = g_finishRadius[ct]
    g_finishRadius[ct] = radius

    new bool:hasFinish = g_hasFinish[t]
    g_hasFinish[t] = g_hasFinish[ct]
    g_hasFinish[ct] = hasFinish

    new points = g_points[t]
    g_points[t] = g_points[ct]
    g_points[ct] = points

    if (g_raceStarted)
        show_score()
}

// Out of time: the team with the most points wins. On a tie it's sudden death: the
// round goes on for another minute (again and again), and the next point wins.
public task_kart_time_up()
{
    if (g_raceOver)
        return

    if (g_points[CS_TEAM_T] > g_points[CS_TEAM_CT]) {
        win_race(CS_TEAM_T)
        return
    }
    if (g_points[CS_TEAM_CT] > g_points[CS_TEAM_T]) {
        win_race(CS_TEAM_CT)
        return
    }

    if (!g_suddenDeath) {
        g_suddenDeath = true
        send_event("mk_finallap")
        client_print(0, print_center, "SUDDEN DEATH!\nThe next point wins")
        log_amx("Mario Kart: a %d-%d tie, sudden death", g_points[CS_TEAM_T], g_points[CS_TEAM_CT])
    }
    extend_round(float(KART_SUDDEN_DEATH_TIME))
    set_task(float(KART_SUDDEN_DEATH_TIME), "task_kart_time_up", TASK_KART_TIME_UP)
    show_score()
}

// Seconds left on the round timer
Float:round_time_left()
{
    return float(get_gamerules_int("CHalfLifeMultiplay", "m_iRoundTimeSecs"))
        - (get_gametime() - get_gamerules_float("CHalfLifeMultiplay", "m_fRoundCount"))
}

// Puts more time on the round timer, and on everyone's clock
extend_round(Float:seconds)
{
    set_gamerules_int("CHalfLifeMultiplay", "m_iRoundTimeSecs", get_gamerules_int("CHalfLifeMultiplay", "m_iRoundTimeSecs") + floatround(seconds))
    message_begin(MSG_ALL, get_user_msgid("RoundTime"))
    write_short(floatround(round_time_left()))
    message_end()
}

bool:is_racer_team(CsTeams:team)
{
    return team == CS_TEAM_T || team == CS_TEAM_CT
}

// A team's finish line is the middle of where the other team spawned this round,
// or of the other team's spawn points if nobody is on it
set_finish(CsTeams:team, CsTeams:other, const spawnClass[])
{
    new Float:points[64][3], num
    new players[MAX_PLAYERS], count
    get_players(players, count, "a")
    for (new i; i < count && num < sizeof points; i++) {
        if (cs_get_user_team(players[i]) == other) {
            copy_vector(g_spawnOrigin[players[i]], points[num])
            num++
        }
    }

    if (!num) {
        new ent = -1
        while ((ent = find_ent_by_class(ent, spawnClass)) && num < sizeof points)
            pev(ent, pev_origin, points[num++])
    }

    g_hasFinish[team] = num > 0
    if (!num)
        return

    new Float:center[3]
    for (new i; i < num; i++) {
        for (new axis; axis < 3; axis++)
            center[axis] += points[i][axis] / float(num)
    }

    // Big enough to cover the spawn, but not half the map
    new Float:radius
    for (new i; i < num; i++)
        radius = floatmax(radius, flat_distance(points[i], center))
    g_finishRadius[team] = floatclamp(radius + 64.0, 128.0, 320.0)
    copy_vector(center, g_finish[team])
}

copy_vector(const Float:from[3], Float:to[3])
{
    to[0] = from[0]
    to[1] = from[1]
    to[2] = from[2]
}

Float:flat_distance(const Float:a[3], const Float:b[3])
{
    return floatsqroot((a[0] - b[0]) * (a[0] - b[0]) + (a[1] - b[1]) * (a[1] - b[1]))
}

bool:at_finish(id, CsTeams:team)
{
    new Float:origin[3]
    pev(id, pev_origin, origin)
    return floatabs(origin[2] - g_finish[team][2]) < 100.0 && flat_distance(origin, g_finish[team]) < g_finishRadius[team]
}

// 0.0 at the spawn, 1.0 at the finish, in a straight line
Float:race_progress(id)
{
    new CsTeams:team = cs_get_user_team(id)
    if (!is_racer_team(team) || !g_hasFinish[team] || g_raceLength[id] <= 0.0)
        return 0.0

    new Float:origin[3]
    pev(id, pev_origin, origin)
    return floatclamp(1.0 - get_distance_f(origin, g_finish[team]) / g_raceLength[id], 0.0, 1.0)
}

bool:is_enemy(id, other)
{
    return cs_get_user_team(id) != cs_get_user_team(other)
}

public task_kart()
{
    if (g_raceOver)
        return

    g_kartTicks++
    new Float:now = get_gametime()
    new players[MAX_PLAYERS], num
    get_players(players, num, "a")
    for (new i; i < num; i++) {
        new id = players[i]
        new CsTeams:team = cs_get_user_team(id)
        if (!is_racer_team(team))
            continue

        update_kart_speed(id, now)
        update_kart_glow(id, now)
        if (g_trailUntil[id] > 0.0 && now >= g_trailUntil[id]) {
            kill_trail(id)
            g_trailUntil[id] = 0.0
        }

        if (g_hasFinish[team] && at_finish(id, team)) {
            score_point(id)
            if (g_raceOver)
                return
            continue
        }

        if (now < g_starUntil[id]) {
            star_hits(id)
            new color = (g_kartTicks + id) % sizeof RAINBOW
            boost_light(id, RAINBOW[color][0], RAINBOW[color][1], RAINBOW[color][2])
        } else if (now < g_boostUntil[id]) {
            boost_light(id, 255, 140, 0)
        }

        if (g_item[id] != ITEM_NONE) {
            if (is_user_bot(id) && now >= g_botUseAt[id] && !g_frozen[id])
                use_item(id)
            else if (g_kartTicks % 5 == 0)
                show_item_hud(id)
        }
    }

    update_kart_entities(now)
    if (g_kartTicks % 10 == 0)
        show_score()
}

update_kart_speed(id, Float:now)
{
    new Float:speed
    if (now < g_starUntil[id] || now < g_boostUntil[id])
        speed = KART_BOOST_SPEED
    else if (now < g_slowUntil[id])
        speed = g_slowSpeed[id]

    if (speed != g_kartSpeed[id]) {
        g_kartSpeed[id] = speed
        ExecuteHamB(Ham_CS_Player_ResetMaxSpeed, id)
    }
}

// Stars shine in rainbow colors, and a blue shell's target glows blue
update_kart_glow(id, Float:now)
{
    if (now < g_starUntil[id]) {
        new color = (g_kartTicks + id) % sizeof RAINBOW
        glow(id, RAINBOW[color][0], RAINBOW[color][1], RAINBOW[color][2])
    } else if (g_blueShellFrom[id]) {
        glow(id, 0, 80, 255)
    } else {
        set_user_rendering(id)
    }
}

glow(ent, r, g, b)
{
    new Float:color[3]
    color[0] = float(r)
    color[1] = float(g)
    color[2] = float(b)
    set_pev(ent, pev_renderfx, kRenderFxGlowShell)
    set_pev(ent, pev_rendercolor, color)
    set_pev(ent, pev_rendermode, kRenderNormal)
    set_pev(ent, pev_renderamt, 20.0)
}

show_item_hud(id)
{
    set_hudmessage(255, 210, 0, -1.0, 0.72, 0, 0.0, 0.6, 0.0, 0.0, -1)
    if (g_item[id] == ITEM_FIREFLOWER)
        ShowSyncHudMsg(id, g_hudSync, "[ %s x%d ]\npress USE (E) or FLASHLIGHT (F)", ITEM_NAME[g_item[id]], g_itemUses[id])
    else
        ShowSyncHudMsg(id, g_hudSync, "[ %s ]\npress USE (E) or FLASHLIGHT (F)", ITEM_NAME[g_item[id]])
}

// The score at the top of everyone's screen
show_score()
{
    set_hudmessage(255, 255, 255, -1.0, 0.1, 0, 0.0, 1.1, 0.0, 0.0, -1)
    if (g_suddenDeath)
        ShowSyncHudMsg(0, g_scoreSync, "Terrorists %d - %d Counter-Terrorists\nSUDDEN DEATH: the next point wins", g_points[CS_TEAM_T], g_points[CS_TEAM_CT])
    else
        ShowSyncHudMsg(0, g_scoreSync, "Terrorists %d - %d Counter-Terrorists\nfirst to %d", g_points[CS_TEAM_T], g_points[CS_TEAM_CT], KART_POINTS)
}

// Made it to the enemy spawn: a point for the team, and back to your own spawn
score_point(id)
{
    new CsTeams:team = cs_get_user_team(id)
    g_points[team]++

    new playerId[MAX_AUTHID_LENGTH]
    get_player_id(id, playerId, charsmax(playerId))
    send_event("mk_point", playerId)
    client_print(0, print_chat, "%n scored! Terrorists %d - %d Counter-Terrorists", id, g_points[CS_TEAM_T], g_points[CS_TEAM_CT])
    show_score()

    if (g_points[team] >= KART_POINTS || g_suddenDeath) {
        win_race(team)
        return
    }

    g_nextSendBack[id] = 0.0
    send_back(id, 255, 210, 0)
    client_print(id, print_center, "POINT!")

    // One more point wins it
    if (!g_finalLap && g_points[team] == KART_POINTS - 1) {
        g_finalLap = true
        send_event("mk_finallap")
        client_print(0, print_center, "FINAL LAP!")
    }
}

// The race is won: everyone stops and the win sound plays. Then the losers are
// slain (which ends the round), and the game pauses while they drink half a beer
// (the web app counts it) to mk_finished.
win_race(CsTeams:team)
{
    g_raceOver = true
    g_raceWinner = team
    remove_task(TASK_KART)
    remove_task(TASK_KART_TIME_UP)

    // Time for the win sound before the round timer runs out
    new Float:needed = KART_WIN_SOUND_TIME + 3.0
    new Float:left = round_time_left()
    if (left < needed)
        extend_round(needed - left)

    send_event("mk_win", team == CS_TEAM_T ? "TERRORIST" : "CT")
    client_print(0, print_center, "%s WIN THE RACE!", team == CS_TEAM_T ? "TERRORISTS" : "COUNTER-TERRORISTS")
    log_amx("Mario Kart: the %s won the race", team == CS_TEAM_T ? "terrorists" : "counter-terrorists")
    refresh_player_stats_soon()

    new players[MAX_PLAYERS], num
    get_players(players, num, "a")
    for (new i; i < num; i++) {
        new id = players[i]
        remove_task(TASK_UNFREEZE + id)
        g_frozen[id] = true
        ExecuteHamB(Ham_CS_Player_ResetMaxSpeed, id)
    }

    set_task(KART_WIN_SOUND_TIME, "task_kart_finished", TASK_KART_FINISHED)
}

public task_kart_finished()
{
    end_race_round()
    send_event("mk_finished")
    client_print(0, print_chat, "The losers drink half a beer!")
    g_kartEndPause = true
    pause_game("the Mario Kart race is over")
}

// Slaying the losers ends the round
end_race_round()
{
    if (g_raceWinner == CS_TEAM_UNASSIGNED)
        return

    new CsTeams:winner = g_raceWinner
    g_raceWinner = CS_TEAM_UNASSIGNED
    new players[MAX_PLAYERS], num
    get_players(players, num, "a")
    for (new i; i < num; i++) {
        new CsTeams:team = cs_get_user_team(players[i])
        if (team != winner && is_racer_team(team))
            user_kill(players[i], 1)
    }
}

// A kill in all but name (by knife or fireball): the victim goes back to their spawn,
// frozen there to drink (the web app counts their sips), and the killer gets a frag
// and some money for an enemy
kart_kill(attacker, victim, const weapon[])
{
    if (!send_back(victim))
        return

    freeze_player(victim)
    g_boostOnUnfreeze[victim] = true
    new attackerId[MAX_AUTHID_LENGTH], victimId[MAX_AUTHID_LENGTH]
    get_player_id(victim, victimId, charsmax(victimId))
    if (is_user_connected(attacker)) {
        get_player_id(attacker, attackerId, charsmax(attackerId))
        if (attacker != victim && is_enemy(attacker, victim)) {
            add_money(attacker, KART_KILL_MONEY)
            add_frag(attacker)
        }
        client_print(0, print_chat, "%n sent %n back to the start!", attacker, victim)
    } else {
        copy(attackerId, charsmax(attackerId), victimId)
    }
    send_event("mk_knifed", attackerId, victimId, "", weapon)
    refresh_player_stats_soon()
}

// One more frag on the in-game scoreboard
add_frag(id)
{
    new frags = get_user_frags(id) + 1
    set_user_frags(id, frags)
    message_begin(MSG_ALL, g_msgScoreInfo)
    write_byte(id)
    write_short(frags)
    write_short(cs_get_user_deaths(id))
    write_short(0)
    write_short(_:cs_get_user_team(id))
    message_end()
}

// Only an enemy's knife hurts, and nobody dies: the hit that would kill sends the
// player back to their spawn with full health instead. So does a deadly fall into
// a pit or the like.
public on_player_take_damage(victim, inflictor, attacker, Float:damage, damagebits)
{
    if (g_mode != MODE_KART)
        return HAM_IGNORED

    if (!g_raceStarted || g_raceOver || !is_user_alive(victim))
        return HAM_SUPERCEDE

    if (1 <= attacker <= MAX_PLAYERS) {
        if (attacker == victim || inflictor != attacker || !is_user_alive(attacker) || !is_enemy(attacker, victim)
            || get_user_weapon(attacker) != CSW_KNIFE || get_gametime() < g_starUntil[victim])
            return HAM_SUPERCEDE

        if (damage < float(get_user_health(victim)))
            return HAM_IGNORED

        kart_kill(attacker, victim, "knife")
    } else if (~damagebits & DMG_FALL && damage >= 50.0) {
        send_back(victim)
    }
    return HAM_SUPERCEDE
}

public on_hostage_use(hostage)
{
    // +use fires items, and hostages stay home
    return g_mode == MODE_KART ? HAM_SUPERCEDE : HAM_IGNORED
}

// Teleports a player to where they spawned (or a free spawn point of their team),
// with full health, no boost, star or slow, and a flash of color
bool:send_back(id, r = 255, g = 0, b = 0)
{
    new Float:now = get_gametime()
    if (now < g_nextSendBack[id])
        return false
    g_nextSendBack[id] = now + 1.0

    new Float:origin[3]
    find_free_spawn(id, origin)
    engfunc(EngFunc_SetOrigin, id, origin)
    set_pev(id, pev_angles, g_spawnAngles[id])
    set_pev(id, pev_v_angle, g_spawnAngles[id])
    set_pev(id, pev_fixangle, 1)
    set_pev(id, pev_velocity, Float:{ 0.0, 0.0, 0.0 })
    set_user_health(id, 100)
    clear_effects(id)
    screen_fade(id, 1.0, r, g, b, 180)
    return true
}

// The spawn point closest to where they spawned, as their own may be taken. Not
// by team: after a half-time switch, players still start where they spawned.
// Ends mushrooms, stars, slows and spinning (a held item is kept)
clear_effects(id)
{
    g_boostUntil[id] = 0.0
    g_starUntil[id] = 0.0
    g_slowUntil[id] = 0.0
    g_spinStart[id] = 0.0
    if (g_trailUntil[id] > 0.0) {
        kill_trail(id)
        g_trailUntil[id] = 0.0
    }
    update_kart_speed(id, get_gametime())
}

find_free_spawn(id, Float:origin[3])
{
    copy_vector(g_spawnOrigin[id], origin)
    if (is_hull_free(id, origin))
        return

    new const SPAWN_CLASSES[][] = { "info_player_start", "info_player_deathmatch" }
    new Float:point[3], Float:best = -1.0
    for (new i; i < sizeof SPAWN_CLASSES; i++) {
        new ent = -1
        while ((ent = find_ent_by_class(ent, SPAWN_CLASSES[i]))) {
            pev(ent, pev_origin, point)
            new Float:distance = get_distance_f(point, g_spawnOrigin[id])
            if ((best < 0.0 || distance < best) && is_hull_free(id, point)) {
                best = distance
                copy_vector(point, origin)
            }
        }
    }

    // Every spawn point is taken: their own anyway
    if (best < 0.0)
        copy_vector(g_spawnOrigin[id], origin)
}

bool:is_hull_free(id, const Float:origin[3])
{
    engfunc(EngFunc_TraceHull, origin, origin, DONT_IGNORE_MONSTERS, HULL_HUMAN, id, 0)
    return !get_tr2(0, TR_StartSolid) && !get_tr2(0, TR_AllSolid) && get_tr2(0, TR_InOpen)
}

// Fires the held item on a fresh press of +use or the flashlight key (which then
// doesn't turn the flashlight on)
kart_cmd_start(id, uc)
{
    new result = FMRES_IGNORED
    new buttons = get_uc(uc, UC_Buttons)
    new bool:fire = (buttons & IN_USE) && !g_useHeld[id]
    g_useHeld[id] = (buttons & IN_USE) != 0

    if (get_uc(uc, UC_Impulse) == 100) {
        set_uc(uc, UC_Impulse, 0)
        fire = true
        result = FMRES_HANDLED
    }

    if (fire && g_item[id] != ITEM_NONE && g_raceStarted && !g_raceOver && !g_frozen[id])
        use_item(id)
    return result
}

// ----------------------------------------------------------------------------
// Mario Kart items
// ----------------------------------------------------------------------------

public on_itembox_touch(box, id)
{
    if (g_mode != MODE_KART || !g_raceStarted || g_raceOver || !is_user_alive(id) || g_item[id] != ITEM_NONE)
        return

    // Taken: it comes back after a while (see update_kart_entities)
    set_pev(box, pev_solid, SOLID_NOT)
    set_pev(box, pev_effects, pev(box, pev_effects) | EF_NODRAW)
    set_pev(box, pev_fuser1, get_gametime() + KART_BOX_RESPAWN)

    give_random_item(id)
}

give_random_item(id)
{
    new CsTeams:team = cs_get_user_team(id)
    new CsTeams:other = team == CS_TEAM_T ? CS_TEAM_CT : CS_TEAM_T
    new tier = g_points[team] < g_points[other] ? 1 : 0
    new total
    for (new KartItem:item = ITEM_MUSHROOM; item < KartItem; item++)
        total += ITEM_ODDS[tier][item]

    new roll = random(total)
    for (new KartItem:item = ITEM_MUSHROOM; item < KartItem; item++) {
        roll -= ITEM_ODDS[tier][item]
        if (roll < 0) {
            g_item[id] = item
            break
        }
    }

    g_itemUses[id] = g_item[id] == ITEM_FIREFLOWER ? KART_FIREBALLS : 1
    g_botUseAt[id] = get_gametime() + random_float(1.0, 5.0)
    show_item_hud(id)
}

use_item(id)
{
    new KartItem:item = g_item[id]
    if (--g_itemUses[id] > 0) {
        // Fire flower shots left; bots fire the next one soon
        g_botUseAt[id] = get_gametime() + random_float(0.4, 1.0)
        show_item_hud(id)
    } else {
        g_item[id] = ITEM_NONE
        ClearSyncHud(id, g_hudSync)
    }

    new playerId[MAX_AUTHID_LENGTH]
    get_player_id(id, playerId, charsmax(playerId))
    send_event(ITEM_EVENT[item], playerId)

    switch (item) {
        case ITEM_MUSHROOM: use_mushroom(id)
        case ITEM_BANANA: use_banana(id)
        case ITEM_GREENSHELL: use_greenshell(id)
        case ITEM_STAR: use_star(id)
        case ITEM_LIGHTNING: use_lightning(id)
        case ITEM_BLUESHELL: use_blueshell(id)
        case ITEM_BOBOMB: use_bobomb(id)
        case ITEM_FIREFLOWER: use_fireflower(id)
    }
}

// Mushroom: 3 seconds of speed, and a push forward
use_mushroom(id)
{
    g_boostUntil[id] = get_gametime() + 3.0
    boost(id, 3.0)
}

// Star: the mushroom's boost for 5 seconds, glowing in rainbow colors (see
// update_kart_glow). Nothing can touch you, and anyone you run into spins out.
use_star(id)
{
    g_starUntil[id] = get_gametime() + KART_STAR_TIME
    boost(id, KART_STAR_TIME)
}

// Off to a flying start: a short mushroom boost, if they're holding forward
start_boost(id)
{
    if (~pev(id, pev_button) & IN_FORWARD)
        return

    new Float:until = get_gametime() + KART_START_BOOST_TIME
    if (until > g_boostUntil[id]) {
        g_boostUntil[id] = until
        boost(id, KART_START_BOOST_TIME)
    }
}

// Speeds up for a while (the reason is in g_boostUntil or g_starUntil), with a
// push forward and a streak behind
boost(id, Float:seconds)
{
    new Float:now = get_gametime()
    set_trail(id, now + seconds, 255, 140, 0)
    update_kart_speed(id, now)

    new Float:ahead[3], Float:velocity[3]
    flat_forward(id, ahead)
    pev(id, pev_velocity, velocity)
    velocity[0] = ahead[0] * 450.0
    velocity[1] = ahead[1] * 450.0
    set_pev(id, pev_velocity, velocity)
}

star_hits(id)
{
    new Float:origin[3], Float:otherOrigin[3]
    pev(id, pev_origin, origin)
    new players[MAX_PLAYERS], num
    get_players(players, num, "a")
    for (new i; i < num; i++) {
        new other = players[i]
        if (other == id || !is_racer_team(cs_get_user_team(other)))
            continue
        pev(other, pev_origin, otherOrigin)
        if (get_distance_f(origin, otherOrigin) < 64.0)
            spin_out(other, id, "star")
    }
}

// Banana: dropped behind you, and spins out the first player to run over it,
// teammates too (and you, if you turn back for it)
use_banana(id)
{
    new Float:origin[3], Float:ahead[3], Float:target[3]
    pev(id, pev_origin, origin)
    flat_forward(id, ahead)
    for (new axis; axis < 2; axis++)
        target[axis] = origin[axis] - ahead[axis] * 64.0
    target[2] = origin[2] - 16.0
    origin[2] -= 16.0
    clip_to_world(id, origin, target, 16.0)

    new banana = create_kart_entity("nobel_banana", BANANA_MODEL, target, Float:{ -12.0, -12.0, 0.0 }, Float:{ 12.0, 12.0, 12.0 }, SOLID_TRIGGER, MOVETYPE_TOSS, id)
    if (!banana)
        return
    set_pev(banana, pev_fuser1, get_gametime() + 1.0)
    glow(banana, 255, 230, 0)
}

public on_banana_touch(banana, id)
{
    new Float:dropperSafeUntil
    pev(banana, pev_fuser1, dropperSafeUntil)
    if (!is_user_alive(id) || id == pev(banana, pev_owner) && get_gametime() < dropperSafeUntil)
        return

    // A star runs it over without spinning out
    spin_out(id, pev(banana, pev_owner), "banana")
    kill_entity(banana)
}

// Green shell: fired straight ahead, bouncing off walls, and spins out the first
// player it hits: teammates, or yourself once it has left your hands
use_greenshell(id)
{
    new Float:origin[3], Float:ahead[3], Float:start[3]
    pev(id, pev_origin, origin)
    flat_forward(id, ahead)
    origin[2] -= 18.0
    for (new axis; axis < 2; axis++)
        start[axis] = origin[axis] + ahead[axis] * 32.0
    start[2] = origin[2]
    clip_to_world(id, origin, start, 8.0)

    new shell = create_kart_entity("nobel_shell", SHELL_MODEL, start, Float:{ -6.0, -6.0, -6.0 }, Float:{ 6.0, 6.0, 6.0 }, SOLID_BBOX, MOVETYPE_BOUNCEMISSILE, id)
    if (!shell)
        return

    new Float:velocity[3]
    velocity[0] = ahead[0] * KART_SHELL_SPEED
    velocity[1] = ahead[1] * KART_SHELL_SPEED
    set_pev(shell, pev_velocity, velocity)
    set_pev(shell, pev_vuser1, ahead)
    set_pev(shell, pev_fuser1, get_gametime() + KART_SHELL_LIFETIME)
    // The engine never lets an entity hit its owner, so the shooter is also kept
    // here, and the owner is let go shortly (see steer_shell)
    set_pev(shell, pev_iuser2, id)
    set_pev(shell, pev_fuser3, get_gametime() + 0.3)
    glow(shell, 0, 255, 0)
    beam_follow(shell, 0, 255, 0)
}

public on_shell_touch(shell, id)
{
    if (!is_user_alive(id))
        return

    new shooter = pev(shell, pev_iuser2)
    if (spin_out(id, shooter, "greenshell")) {
        hit_light(id, 0, 255, 0)
        if (shooter != id)
            add_money(shooter, KART_SHELL_HIT_MONEY)
    }
    kill_entity(shell)
}

// Shells keep their speed along the ground: the engine bounces them off walls,
// this adds gravity, takes most of the height out of each bounce, and speeds them
// up again
steer_shell(shell, Float:now)
{
    new Float:ownerSafeUntil
    pev(shell, pev_fuser3, ownerSafeUntil)
    if (pev(shell, pev_owner) && now >= ownerSafeUntil)
        set_pev(shell, pev_owner, 0)

    new Float:velocity[3], Float:direction[3]
    pev(shell, pev_velocity, velocity)
    pev(shell, pev_vuser1, direction)

    new Float:speed = floatsqroot(velocity[0] * velocity[0] + velocity[1] * velocity[1])
    if (speed > 50.0) {
        direction[0] = velocity[0] / speed
        direction[1] = velocity[1] / speed
        set_pev(shell, pev_vuser1, direction)
    }

    new Float:target = pev(shell, pev_iuser1) ? KART_FIREBALL_SPEED : KART_SHELL_SPEED
    velocity[0] = direction[0] * target
    velocity[1] = direction[1] * target

    // Falling at the last check and rising now: it bounced
    new Float:lastRise
    pev(shell, pev_fuser2, lastRise)
    if (lastRise < 0.0 && velocity[2] > 0.0)
        velocity[2] *= 0.3
    velocity[2] = floatmin(velocity[2], 150.0) - 80.0
    set_pev(shell, pev_fuser2, velocity[2])
    set_pev(shell, pev_velocity, velocity)
    set_pev(shell, pev_flags, pev(shell, pev_flags) & ~FL_ONGROUND)
}

// Lightning: strikes everyone else, teammates too, who are slowed down for 4 seconds
// and lose their item
use_lightning(id)
{
    new playerId[MAX_AUTHID_LENGTH], victimId[MAX_AUTHID_LENGTH]
    get_player_id(id, playerId, charsmax(playerId))

    new players[MAX_PLAYERS], num
    get_players(players, num, "a")
    for (new i; i < num; i++) {
        new victim = players[i]
        if (victim == id || !is_racer_team(cs_get_user_team(victim)) || !can_be_hit(victim))
            continue

        lightning_bolt(victim)
        screen_fade(victim, 1.0, 255, 255, 255, 180)
        slow_down(victim, 150.0, 4.0)
        g_item[victim] = ITEM_NONE
        g_itemUses[victim] = 0
        ClearSyncHud(victim, g_hudSync)

        get_player_id(victim, victimId, charsmax(victimId))
        send_event("mk_zap", playerId, victimId)
    }
}

// Blue shell: flies through walls and everything to the enemy furthest ahead, who
// glows blue until it lands and is stunned: a black screen and frozen for 3 seconds
use_blueshell(id)
{
    new target, Float:best = -1.0
    new players[MAX_PLAYERS], num
    get_players(players, num, "a")
    for (new i; i < num; i++) {
        new other = players[i]
        if (!is_enemy(id, other) || !is_racer_team(cs_get_user_team(other)) || g_blueShellFrom[other])
            continue
        new Float:progress = race_progress(other)
        if (progress > best) {
            best = progress
            target = other
        }
    }

    if (!target) {
        client_print(id, print_center, "The blue shell found nobody to hit")
        return
    }

    g_blueShellFrom[target] = id
    client_print(target, print_center, "BLUE SHELL INCOMING!")
    set_task(KART_BLUESHELL_DELAY, "task_blueshell", TASK_KART_BLUESHELL + target)

    new Float:origin[3]
    pev(id, pev_origin, origin)
    origin[2] += 32.0
    new shell = create_kart_entity("nobel_blueshell", SHELL_MODEL, origin, Float:{ -6.0, -6.0, -6.0 }, Float:{ 6.0, 6.0, 6.0 }, SOLID_NOT, MOVETYPE_NOCLIP, id)
    if (!shell)
        return

    new Float:now = get_gametime()
    set_pev(shell, pev_enemy, target)
    set_pev(shell, pev_fuser1, now + KART_BLUESHELL_DELAY)
    set_pev(shell, pev_fuser2, now + KART_BLUESHELL_RISE)
    glow(shell, 0, 80, 255)
    beam_follow(shell, 0, 80, 255)
    steer_blueshell(shell, now)
}

// First it rises, spinning fast, then heads for the target so it arrives just as
// it lands (with the end of its sound), coming down on them from above
steer_blueshell(shell, Float:now)
{
    new Float:riseEnds
    pev(shell, pev_fuser2, riseEnds)
    if (now < riseEnds) {
        set_pev(shell, pev_velocity, Float:{ 0.0, 0.0, 120.0 })
        set_pev(shell, pev_avelocity, Float:{ 0.0, 1080.0, 0.0 })
        return
    }
    set_pev(shell, pev_avelocity, Float:{ 0.0, 360.0, 0.0 })

    new target = pev(shell, pev_enemy)
    new Float:landsAt
    pev(shell, pev_fuser1, landsAt)
    if (!is_user_alive(target) || now >= landsAt) {
        kill_entity(shell)
        return
    }

    new Float:from[3], Float:to[3], Float:velocity[3]
    pev(shell, pev_origin, from)
    pev(target, pev_origin, to)
    new Float:left = landsAt - now
    to[2] += 16.0 + 150.0 * left / (KART_BLUESHELL_DELAY - KART_BLUESHELL_RISE)

    left = floatmax(left, KART_TICK)
    for (new axis; axis < 3; axis++)
        velocity[axis] = (to[axis] - from[axis]) / left
    set_pev(shell, pev_velocity, velocity)
}

public task_blueshell(taskid)
{
    new target = taskid - TASK_KART_BLUESHELL
    new from = g_blueShellFrom[target]
    g_blueShellFrom[target] = 0

    new shell = -1
    while ((shell = find_ent_by_class(shell, "nobel_blueshell"))) {
        if (pev(shell, pev_enemy) == target)
            kill_entity(shell)
    }

    if (!can_be_hit(target))
        return

    new Float:origin[3]
    pev(target, pev_origin, origin)
    explosion(origin)
    stun(target)
    send_hit("mk_stun", from, target, "blueshell")
}

// Blown up by a blue shell or bob-omb: a black screen, and frozen and spinning for 3 seconds
stun(id)
{
    screen_fade(id, KART_STUN_TIME, 0, 0, 0, 255)
    freeze_player(id, KART_STUN_TIME, false)
    spin(id, KART_STUN_TIME, 3)
    hop(id, 250.0)
}

// Slowed down for a while; the strongest slow wins
slow_down(id, Float:speed, Float:seconds)
{
    new Float:now = get_gametime()
    g_slowSpeed[id] = now < g_slowUntil[id] ? floatmin(g_slowSpeed[id], speed) : speed
    g_slowUntil[id] = floatmax(g_slowUntil[id], now + seconds)
    update_kart_speed(id, now)
}

// Bob-omb: lobbed forward a fixed distance, and goes off when it lands or hits someone,
// blowing up everyone close by, teammates and the thrower too
use_bobomb(id)
{
    new Float:origin[3], Float:ahead[3], Float:start[3]
    pev(id, pev_origin, origin)
    flat_forward(id, ahead)
    for (new axis; axis < 2; axis++)
        start[axis] = origin[axis] + ahead[axis] * 24.0
    start[2] = origin[2] + 16.0
    clip_to_world(id, origin, start, 8.0)

    new bomb = create_kart_entity("nobel_bobomb", BOBOMB_MODEL, start, Float:{ -6.0, -6.0, -6.0 }, Float:{ 6.0, 6.0, 6.0 }, SOLID_BBOX, MOVETYPE_TOSS, id)
    if (!bomb)
        return

    new Float:velocity[3]
    velocity[0] = ahead[0] * KART_BOBOMB_SPEED
    velocity[1] = ahead[1] * KART_BOBOMB_SPEED
    velocity[2] = KART_BOBOMB_LIFT
    set_pev(bomb, pev_velocity, velocity)
    set_pev(bomb, pev_avelocity, Float:{ 300.0, 0.0, 0.0 })
    set_pev(bomb, pev_iuser2, id)
    set_pev(bomb, pev_fuser1, get_gametime() + KART_BOBOMB_FUSE)
    glow(bomb, 255, 40, 0)
}

public on_bobomb_touch(bomb, id)
{
    bobomb_explode(bomb)
}

bobomb_explode(bomb)
{
    if (pev(bomb, pev_flags) & FL_KILLME)
        return

    new thrower = pev(bomb, pev_iuser2)
    new Float:origin[3], Float:otherOrigin[3]
    pev(bomb, pev_origin, origin)
    kill_entity(bomb)
    explosion(origin)

    // The explosion's sound is mk_stun, the same as the blue shell's
    new throwerId[MAX_AUTHID_LENGTH]
    if (is_user_connected(thrower))
        get_player_id(thrower, throwerId, charsmax(throwerId))
    send_event("mk_boom", throwerId, "", "mk_stun")

    new players[MAX_PLAYERS], num
    get_players(players, num, "a")
    for (new i; i < num; i++) {
        new victim = players[i]
        pev(victim, pev_origin, otherOrigin)
        if (!is_racer_team(cs_get_user_team(victim)) || !can_be_hit(victim) || get_distance_f(origin, otherOrigin) > KART_BOBOMB_RADIUS)
            continue
        stun(victim)
        send_hit("mk_bombed", thrower, victim, "bobomb")
        if (victim != thrower)
            add_money(thrower, KART_BOBOMB_HIT_MONEY)
    }
}

// Fire flower: one fireball per press, straight ahead
use_fireflower(id)
{
    new Float:origin[3], Float:ahead[3], Float:start[3]
    pev(id, pev_origin, origin)
    flat_forward(id, ahead)
    for (new axis; axis < 2; axis++)
        start[axis] = origin[axis] + ahead[axis] * 24.0
    start[2] = origin[2]
    clip_to_world(id, origin, start, 4.0)

    new ball = create_kart_entity("nobel_fireball", FIREBALL_SPRITE, start, Float:{ -3.0, -3.0, -3.0 }, Float:{ 3.0, 3.0, 3.0 }, SOLID_BBOX, MOVETYPE_BOUNCEMISSILE, id)
    if (!ball)
        return

    new Float:velocity[3]
    velocity[0] = ahead[0] * KART_FIREBALL_SPEED
    velocity[1] = ahead[1] * KART_FIREBALL_SPEED
    set_pev(ball, pev_velocity, velocity)
    set_pev(ball, pev_vuser1, ahead)
    set_pev(ball, pev_fuser1, get_gametime() + KART_FIREBALL_LIFETIME)
    set_pev(ball, pev_iuser2, id)
    // Steered like a green shell, at its own speed (see steer_shell)
    set_pev(ball, pev_iuser1, 1)
    set_pev(ball, pev_fuser3, get_gametime() + 0.3)
    set_pev(ball, pev_rendermode, kRenderTransAdd)
    set_pev(ball, pev_renderamt, 255.0)
    set_pev(ball, pev_scale, 0.4)
    beam_follow(ball, 255, 90, 0)
}

public on_fireball_touch(ball, id)
{
    if (!is_user_alive(id))
        return

    new shooter = pev(ball, pev_iuser2)
    kill_entity(ball)
    if (!can_be_hit(id))
        return

    slow_down(id, KART_FIREBALL_SLOW_SPEED, KART_FIREBALL_SLOW_TIME)
    screen_fade(id, 0.5, 255, 80, 0, 120)
    hit_light(id, 255, 0, 0)

    new health = get_user_health(id)
    if (health > KART_FIREBALL_DAMAGE) {
        set_user_health(id, health - KART_FIREBALL_DAMAGE)
        send_hit("mk_hit", shooter, id, "fireflower", "mk_hit_fireflower")
        if (shooter != id)
            add_money(shooter, KART_FIREBALL_HIT_MONEY)
    } else {
        kart_kill(shooter, id, "grenade")
    }
}

bool:can_be_hit(id)
{
    return is_user_alive(id) && g_raceStarted && !g_raceOver && get_gametime() >= g_starUntil[id]
}

// Hit by a banana, shell or star: a hop, and the view spins while frozen for a moment
bool:spin_out(victim, attacker, const item[])
{
    if (!can_be_hit(victim))
        return false

    freeze_player(victim, KART_SPIN_TIME, false)
    spin(victim, KART_SPIN_TIME, 2)
    hop(victim, 200.0)
    // Each item has its own hit sound (mk_hit_banana etc.), or the general mk_hit
    new sound[32]
    formatex(sound, charsmax(sound), "mk_hit_%s", item)
    send_hit("mk_hit", attacker, victim, item, sound)
    return true
}

// Turns the view around a number of times (see on_player_prethink)
spin(id, Float:seconds, turns)
{
    new Float:angles[3]
    pev(id, pev_v_angle, angles)
    g_spinYaw[id] = angles[1]
    g_spinTime[id] = seconds
    g_spinTurn[id] = 360.0 * float(turns)
    g_spinStart[id] = get_gametime()
}

// Turns a spinning player's view every frame, fast at first and slowing down,
// ending where they were looking
public on_player_prethink(id)
{
    if (g_spinStart[id] == 0.0)
        return FMRES_IGNORED

    new Float:t = (get_gametime() - g_spinStart[id]) / g_spinTime[id]
    if (t >= 1.0 || !is_user_alive(id)) {
        t = 1.0
        g_spinStart[id] = 0.0
    }

    new Float:angles[3]
    pev(id, pev_v_angle, angles)
    angles[1] = g_spinYaw[id] + g_spinTurn[id] * (1.0 - (1.0 - t) * (1.0 - t))
    set_pev(id, pev_angles, angles)
    set_pev(id, pev_v_angle, angles)
    set_pev(id, pev_fixangle, 1)
    return FMRES_IGNORED
}

// A little knock into the air, lower than a jump (268), and only from the ground:
// on top of a jump it lifts players onto invisible clip brushes they can then walk on
hop(id, Float:speed)
{
    if (~pev(id, pev_flags) & FL_ONGROUND)
        return

    new Float:velocity[3]
    pev(id, pev_velocity, velocity)
    velocity[2] = speed
    set_pev(id, pev_velocity, velocity)
}

// The victim drinks a sip (the web app counts it). `sound` picks another media
// folder than the event's own.
send_hit(const cmd[], attacker, victim, const item[], const sound[] = "")
{
    new attackerId[MAX_AUTHID_LENGTH], victimId[MAX_AUTHID_LENGTH]
    get_player_id(victim, victimId, charsmax(victimId))
    if (is_user_connected(attacker))
        get_player_id(attacker, attackerId, charsmax(attackerId))
    else
        copy(attackerId, charsmax(attackerId), victimId)
    send_event(cmd, attackerId, victimId, sound, item)
    refresh_player_stats_soon()
}

// Item boxes come back a while after they're taken and cycle through the rainbow;
// blue shells home in, and green shells keep going until they expire
update_kart_entities(Float:now)
{
    new ent = -1, Float:respawn
    while ((ent = find_ent_by_class(ent, "nobel_itembox"))) {
        pev(ent, pev_fuser1, respawn)
        if (respawn > 0.0 && now >= respawn) {
            new Float:origin[3]
            pev(ent, pev_origin, origin)
            set_pev(ent, pev_fuser1, 0.0)
            set_pev(ent, pev_effects, pev(ent, pev_effects) & ~EF_NODRAW)
            set_pev(ent, pev_solid, SOLID_TRIGGER)
            engfunc(EngFunc_SetOrigin, ent, origin)
        }
        if (g_kartTicks % 3 == 0) {
            new color = (g_kartTicks / 3 + ent) % sizeof RAINBOW
            glow(ent, RAINBOW[color][0], RAINBOW[color][1], RAINBOW[color][2])
        }
    }

    ent = -1
    while ((ent = find_ent_by_class(ent, "nobel_blueshell")))
        steer_blueshell(ent, now)

    // Bob-ombs blink, and go off when they land or their fuse runs out
    new Float:fuse
    ent = -1
    while ((ent = find_ent_by_class(ent, "nobel_bobomb"))) {
        pev(ent, pev_fuser1, fuse)
        if (pev(ent, pev_flags) & FL_ONGROUND || now >= fuse)
            bobomb_explode(ent)
        else if (g_kartTicks % 2)
            glow(ent, 255, 40, 0)
        else
            glow(ent, 60, 60, 60)
    }

    ent = -1
    while ((ent = find_ent_by_class(ent, "nobel_fireball"))) {
        pev(ent, pev_fuser1, fuse)
        if (now >= fuse)
            kill_entity(ent)
        else
            steer_shell(ent, now)
    }

    new Float:expires
    ent = -1
    while ((ent = find_ent_by_class(ent, "nobel_shell"))) {
        pev(ent, pev_fuser1, expires)
        if (now >= expires)
            kill_entity(ent)
        else
            steer_shell(ent, now)
    }
}

// Item boxes go where players have stood on this map, KART_BOX_SPACING apart all
// over it, and away from both spawns. Weapon spawns fill in on maps with few
// recorded spots.
place_item_boxes()
{
    new Array:candidates = ArrayCreate(3)
    new Float:spot[3]
    for (new i, count = ArraySize(g_spots); i < count; i++) {
        ArrayGetArray(g_spots, i, spot)
        if (away_from_spawns(spot))
            ArrayPushArray(candidates, spot)
    }

    if (ArraySize(candidates) < KART_BOXES / 2) {
        new ent = -1
        while ((ent = find_ent_by_class(ent, "armoury_entity"))) {
            pev(ent, pev_origin, spot)
            spot[2] += 16.0
            if (away_from_spawns(spot))
                ArrayPushArray(candidates, spot)
        }
    }

    new Float:placed[KART_BOXES][3], num
    while (num < KART_BOXES && ArraySize(candidates)) {
        new pick = random(ArraySize(candidates))
        ArrayGetArray(candidates, pick, spot)
        ArrayDeleteItem(candidates, pick)

        new bool:crowded
        for (new i; i < num && !crowded; i++)
            crowded = get_distance_f(spot, placed[i]) < KART_BOX_SPACING

        if (crowded)
            continue

        new box = create_kart_entity("nobel_itembox", g_itemboxModel, spot, Float:{ -16.0, -16.0, -16.0 }, Float:{ 16.0, 16.0, 16.0 }, SOLID_TRIGGER, MOVETYPE_NOCLIP, 0)
        if (!box)
            break
        set_pev(box, pev_avelocity, Float:{ 0.0, 120.0, 0.0 })
        glow(box, 255, 255, 255)
        copy_vector(spot, placed[num++])
    }
    ArrayDestroy(candidates)

    if (!num)
        client_print(0, print_chat, "No item boxes on this map yet: they go where players have been, so play a normal round first.")
    log_amx("Mario Kart: %d item boxes (%d spots recorded on %s)", num, ArraySize(g_spots), g_mapName)
}

bool:away_from_spawns(const Float:spot[3])
{
    for (new CsTeams:team = CS_TEAM_T; team <= CS_TEAM_CT; team++) {
        if (g_hasFinish[team] && get_distance_f(spot, g_finish[team]) < g_finishRadius[team] + 150.0)
            return false
    }
    return true
}

create_kart_entity(const classname[], const model[], const Float:origin[3], const Float:mins[3], const Float:maxs[3], solid, movetype, owner)
{
    new ent = create_entity("info_target")
    if (!ent)
        return 0

    set_pev(ent, pev_classname, classname)
    engfunc(EngFunc_SetModel, ent, model)
    engfunc(EngFunc_SetSize, ent, mins, maxs)
    set_pev(ent, pev_solid, solid)
    set_pev(ent, pev_movetype, movetype)
    set_pev(ent, pev_owner, owner)
    engfunc(EngFunc_SetOrigin, ent, origin)
    return ent
}

// Removes an entity safely from inside its own touch
kill_entity(ent)
{
    kill_trail(ent)
    set_pev(ent, pev_solid, SOLID_NOT)
    set_pev(ent, pev_effects, pev(ent, pev_effects) | EF_NODRAW)
    set_pev(ent, pev_flags, pev(ent, pev_flags) | FL_KILLME)
}

// Where the player is looking, level with the ground
flat_forward(id, Float:ahead[3])
{
    new Float:angles[3]
    pev(id, pev_v_angle, angles)
    angles[0] = 0.0
    angle_vector(angles, ANGLEVECTOR_FORWARD, ahead)
}

// Moves `to` back from any wall between `from` and it, by `margin`
clip_to_world(id, const Float:from[3], Float:to[3], Float:margin)
{
    new Float:hit[3]
    trace_line(id, from, to, hit)
    new Float:length = get_distance_f(from, hit)
    new Float:full = get_distance_f(from, to)
    if (full < 1.0)
        return

    new Float:scale = floatmax(0.0, length - margin) / full
    for (new axis; axis < 3; axis++)
        to[axis] = from[axis] + (to[axis] - from[axis]) * scale
}

// ----------------------------------------------------------------------------
// Mario Kart effects
// ----------------------------------------------------------------------------

set_trail(id, Float:until, r, g, b)
{
    kill_trail(id)
    beam_follow(id, r, g, b)
    g_trailUntil[id] = until
}

beam_follow(ent, r, g, b)
{
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
    write_byte(TE_BEAMFOLLOW)
    write_short(ent)
    write_short(g_sprBeam)
    write_byte(10) // life: 1 second
    write_byte(8) // width
    write_byte(r)
    write_byte(g)
    write_byte(b)
    write_byte(200) // brightness
    message_end()
}

// A colored light around the player for one tick, lighting up their own knife and
// the ground around them
boost_light(id, r, g, b)
{
    dynamic_light(id, r, g, b, 14, 2, 0)
}

// A flash of colored light around a player who was hit, fading out
hit_light(id, r, g, b)
{
    dynamic_light(id, r, g, b, 20, 5, 40)
}

// radius in tens of units, life in tenths of a second, decay in units per second / 10
dynamic_light(id, r, g, b, radius, life, decay)
{
    new Float:origin[3]
    pev(id, pev_origin, origin)
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
    write_byte(TE_DLIGHT)
    write_coord(floatround(origin[0]))
    write_coord(floatround(origin[1]))
    write_coord(floatround(origin[2]))
    write_byte(radius)
    write_byte(r)
    write_byte(g)
    write_byte(b)
    write_byte(life)
    write_byte(decay)
    message_end()
}

kill_trail(ent)
{
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
    write_byte(TE_KILLBEAM)
    write_short(ent)
    message_end()
}

// A bolt from the ceiling (or the sky) down onto the player
lightning_bolt(id)
{
    new Float:origin[3], Float:top[3], Float:hit[3]
    pev(id, pev_origin, origin)
    copy_vector(origin, top)
    top[2] += 1000.0
    trace_line(id, origin, top, hit)

    message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
    write_byte(TE_BEAMPOINTS)
    write_coord(floatround(hit[0]))
    write_coord(floatround(hit[1]))
    write_coord(floatround(hit[2]))
    write_coord(floatround(origin[0]))
    write_coord(floatround(origin[1]))
    write_coord(floatround(origin[2] - 36.0))
    write_short(g_sprLightning)
    write_byte(0) // start frame
    write_byte(10) // frame rate
    write_byte(4) // life: 0.4 seconds
    write_byte(60) // width
    write_byte(40) // noise
    write_byte(255)
    write_byte(255)
    write_byte(160)
    write_byte(255) // brightness
    write_byte(0) // scroll speed
    message_end()
}

// A silent explosion and a blue shockwave (the sound comes from the web app)
explosion(const Float:origin[3])
{
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
    write_byte(TE_EXPLOSION)
    write_coord(floatround(origin[0]))
    write_coord(floatround(origin[1]))
    write_coord(floatround(origin[2]))
    write_short(g_sprExplosion)
    write_byte(30) // scale
    write_byte(15) // frame rate
    write_byte(TE_EXPLFLAG_NOSOUND)
    message_end()

    message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
    write_byte(TE_BEAMCYLINDER)
    write_coord(floatround(origin[0]))
    write_coord(floatround(origin[1]))
    write_coord(floatround(origin[2] - 30.0))
    write_coord(floatround(origin[0]))
    write_coord(floatround(origin[1]))
    write_coord(floatround(origin[2] + 300.0))
    write_short(g_sprRing)
    write_byte(0) // start frame
    write_byte(0) // frame rate
    write_byte(6) // life
    write_byte(30) // width
    write_byte(0) // noise
    write_byte(0)
    write_byte(80)
    write_byte(255)
    write_byte(220) // brightness
    write_byte(0) // speed
    message_end()
}

// The screen starts in a color and fades back to normal
screen_fade(id, Float:seconds, r, g, b, alpha)
{
    message_begin(MSG_ONE, g_msgScreenFade, _, id)
    write_short(min(floatround(seconds * 4096.0), 0xFFFF)) // duration
    write_short(0) // hold time
    write_short(0x0000) // FFADE_IN
    write_byte(r)
    write_byte(g)
    write_byte(b)
    write_byte(alpha)
    message_end()
}

// ----------------------------------------------------------------------------
// Item box spots: where players stand during normal play, saved per map
// ----------------------------------------------------------------------------

public task_record_spots()
{
    if (!g_enabled || ArraySize(g_spots) >= MAX_SPOTS)
        return

    new players[MAX_PLAYERS], num
    get_players(players, num, "a")
    for (new i; i < num; i++) {
        new id = players[i]
        new flags = pev(id, pev_flags)
        new ground = pev(id, pev_groundentity)
        // On solid ground, standing up: not in a vent, on a ladder, in water or on someone's head
        if (~flags & FL_ONGROUND || flags & FL_DUCKING || pev(id, pev_waterlevel) || pev(id, pev_movetype) == MOVETYPE_FLY
            || (1 <= ground <= MAX_PLAYERS))
            continue

        // A box's middle, 20 units above the floor
        new Float:spot[3]
        pev(id, pev_origin, spot)
        spot[2] -= 20.0
        if (!near_spot(spot)) {
            ArrayPushArray(g_spots, spot)
            g_spotsChanged = true
        }
    }
}

bool:near_spot(const Float:spot[3])
{
    new Float:other[3]
    for (new i, count = ArraySize(g_spots); i < count; i++) {
        ArrayGetArray(g_spots, i, other)
        if (get_distance_f(spot, other) < SPOT_SPACING)
            return true
    }
    return false
}

spots_file(path[], len)
{
    get_datadir(path, len)
    format(path, len, "%s/%s", path, SPOTS_DIR)
    if (!dir_exists(path))
        mkdir(path)
    format(path, len, "%s/%s.txt", path, g_mapName)
}

load_spots()
{
    g_spots = ArrayCreate(3)

    new path[PLATFORM_MAX_PATH]
    spots_file(path, charsmax(path))
    new file = fopen(path, "rt")
    if (!file)
        return

    new line[64], x[16], y[16], z[16], Float:spot[3]
    while (fgets(file, line, charsmax(line)) && ArraySize(g_spots) < MAX_SPOTS) {
        if (parse(line, x, charsmax(x), y, charsmax(y), z, charsmax(z)) < 3)
            continue
        spot[0] = str_to_float(x)
        spot[1] = str_to_float(y)
        spot[2] = str_to_float(z)
        ArrayPushArray(g_spots, spot)
    }
    fclose(file)
}

save_spots()
{
    if (!g_spotsChanged)
        return

    new path[PLATFORM_MAX_PATH]
    spots_file(path, charsmax(path))
    new file = fopen(path, "wt")
    if (!file) {
        log_amx("Could not save item box spots to %s", path)
        return
    }

    new Float:spot[3]
    for (new i, count = ArraySize(g_spots); i < count; i++) {
        ArrayGetArray(g_spots, i, spot)
        fprintf(file, "%.0f %.0f %.0f\n", spot[0], spot[1], spot[2])
    }
    fclose(file)
    g_spotsChanged = false
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

    // Nobody can be killed in the Mario Kart round: these are the losers of the race
    if (g_mode == MODE_KART)
        return

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

    g_kartPauseMenu = menu_create("MARIO KART IS OVER", "kart_pause_menu_handler")
    for (new i; i < 8; i++)
        menu_addblank2(g_kartPauseMenu)
    menu_additem(g_kartPauseMenu, "End Mario Kart")
    menu_additem(g_kartPauseMenu, "Race again")
    menu_setprop(g_kartPauseMenu, MPROP_PERPAGE, 0)
}

public pause_menu_handler(id, menu, item)
{
    if (item == 9 && g_paused) {
        log_admin(id, "unpaused the game")
        unpause_game()
    }
    return PLUGIN_HANDLED
}

// 9: back to normal rounds from the next one; 0: Mario Kart again
public kart_pause_menu_handler(id, menu, item)
{
    if (!g_paused || item != 8 && item != 9)
        return PLUGIN_HANDLED

    if (item == 8 && g_mode == MODE_KART) {
        log_admin(id, "ended the %s", MODE_NAME[MODE_KART])
        g_endModeAfterRound = true
        // Before the next round starts, which reads the round time
        restore_kart_cvars()
        client_print(0, print_chat, "That was the last %s!", MODE_NAME[MODE_KART])
    } else {
        log_admin(id, "unpaused the game")
    }
    unpause_game()
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

    if (g_setting[SET_PAUSE] || g_mode == MODE_KART)
        show_pause_menu(g_paused)

    if (!g_paused)
        g_kartEndPause = false

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
            menu_display(players[i], g_kartEndPause ? g_kartPauseMenu : g_pauseMenu)
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
        if (mode == MODE_KART)
            set_kart_cvars()
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

public cmd_nobel_teleswapnow(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1) || !g_enabled)
        return PLUGIN_HANDLED

    if (read_argc() < 3) {
        log_admin(id, "triggered a teleswap")
        if (!random_teleswap())
            console_print(id, "Nobody to swap: both teams need a living player.")
        return PLUGIN_HANDLED
    }

    new name[32], first, second
    read_argv(1, name, charsmax(name))
    first = cmd_target(id, name, CMDTARGET_ONLY_ALIVE | CMDTARGET_ALLOW_SELF)
    read_argv(2, name, charsmax(name))
    second = cmd_target(id, name, CMDTARGET_ONLY_ALIVE | CMDTARGET_ALLOW_SELF)
    if (!first || !second)
        return PLUGIN_HANDLED
    if (first == second) {
        console_print(id, "Pick two different players.")
        return PLUGIN_HANDLED
    }

    log_admin(id, "teleswapped %n and %n", first, second)
    teleswap_players(first, second)
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
