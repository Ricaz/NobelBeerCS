#include <amxmodx>
#include <core>
#include <sockets>
#include <fun>
#include <csx>
#include <cstrike>
#include <core>
#include <amxmisc>
#include <fakemeta>
#include <engine>
#include <hamsandwich>
#include <sqlx>
#include <cellarray>
#include <regex>
#include <nvault>

#pragma ctrlchar '\'
#define PLUGIN "Nobel Beer CS"
#define AUTHOR "Nobel Kollegiet"
#define VERSION "1.9"
#define MAX_FILENAME_LEN 50
#define VAULT_NAME "nobel"
#define VAULT_KEY_MAPEND "mapend"
#define ACCESS_ADMIN ADMIN_SLAY
#define ACCESS_PUBLIC ADMIN_ALL
#define MOD_STATE_STOPPED "STOPPED"
#define MOD_STATE_STARTING "STARTING"
#define MOD_STATE_STARTED "STARTED"
#define MAP_TYPE_DE "de"
#define MAP_TYPE_CS "cs"
#define MAP_TYPE_FY "fy"
#define MAP_TYPE_AS "as"
#define MAP_TYPE_AIM "aim"
#define MAP_TYPE_AWP "awp"

new bool:USE_JSON = false

new bool:ENABLED = false
new bool:PAUSE = false
new bool:SOUND = false
new bool:FLASH = false
new bool:BADUM = false
new bool:KNIFE = false
new bool:FLASHPROTECTION = false

new pauseMenu

new nobel_server_host[50]
new nobel_server_port
new Handle:db
new db_available = true
new mod_state[10] = MOD_STATE_STOPPED
new bool:knife_next = false
new bool:knife_last = false
new Float:user_frozen_time = 5.0
new bool:cannot_move[33]
new player_money[33]
new bool:flash_thrown = false
new cache_sips[33]
new bool:freezetime = true
new bool:defused = false
new bool:exploded = false
new bool:time_elapsed = false
new bool:teams_switched = false
new bool:is_paused = false
new bool:pause_enabled_before_kniferound = false
new round_count = 0
new win_count_t = 0
new win_count_ct = 0
new map_time_half
new Float:round_time
new map_type[4] = MAP_TYPE_DE
new alone_round = false
new first_hostage_touched = false
new screen_fade_msg
new bool:flash_protection_active = false
new Float:flash_protection_time = 12.0
new Float:map_pause_time = 300.0
new vault

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR)
    register_event("HLTV", "round_start", "a", "1=0", "2=0")
    register_event("HLTV", "event_new_round", "a", "1=0", "2=0")
    register_event("DeathMsg", "hook_death", "a")
    register_event("30", "map_change", "a")
    register_event("TeamInfo", "fix_sip_count", "a")
    register_event("CurWeapon", "set_user_speed", "be") 
    register_event("HideWeapon", "set_user_speed", "be") 
    register_event("TextMsg", "hostages_rescued", "a", "2&#All_Hostages_R") 
    register_event("ScreenFade", "event_screenfade", "be", "4=255", "5=255", "6=255", "7>199")
    register_logevent("team_win", 2, "1=Round_End");
    register_logevent("event_round_start", 2, "1=Round_Start")
    register_logevent("bomb_planted_custom", 3, "2=Planted_The_Bomb")
    register_logevent("bomb_explode_custom", 6, "3=Target_Bombed")
    register_logevent("bomb_defused", 3, "2=Defused_The_Bomb")
    register_logevent("hostage_touched", 3, "2=Touched_A_Hostage")
    register_message(get_user_msgid("TextMsg"), "message_textmsg")
    register_forward(FM_UpdateClientData, "fw_UpdateClientData")
    RegisterHam(Ham_Spawn, "player", "player_spawned", 1);
    RegisterHam(Ham_Weapon_WeaponIdle, "weapon_flashbang", "weapon_idle_flashbang")
    RegisterHam(Ham_TraceAttack, "hostage_entity", "hostage_traceattack", false) 
    RegisterHam(Ham_TakeDamage, "hostage_entity", "hostage_damage", false)

    register_concmd("nobel_maps", "cmd_nobel_maps", ACCESS_PUBLIC, "Lists available maps on the server.")
    register_concmd("nobel_pause", "cmd_nobel_pause", ACCESS_ADMIN, "Disable/enable pause.")
    register_concmd("nobel_sound", "cmd_nobel_sound", ACCESS_ADMIN, "Enable/disable sound.")
    register_concmd("nobel_badum", "cmd_nobel_badum", ACCESS_ADMIN, "Enable/disable badum.")
    register_concmd("nobel_theme", "cmd_nobel_theme", ACCESS_ADMIN, "Change sound theme.")
    register_concmd("badum", "cmd_badum", ACCESS_ADMIN, "Plays badum!")
    register_concmd("shutup", "cmd_shutup", ACCESS_ADMIN, "Plays shutup!")
    register_concmd("ready", "cmd_ready", ACCESS_ADMIN, "Plays reeady sound!")
    register_concmd("nobel", "cmd_nobel", ACCESS_ADMIN, "View current settings.")
    register_concmd("nobelstats", "cmd_nobel_stats", ACCESS_ADMIN, "View simple stats.")
    register_concmd("nobel_stats", "cmd_nobel_stats", ACCESS_ADMIN, "View simple stats.")
    register_concmd("nobel_full_stats", "cmd_nobel_full_stats", ACCESS_ADMIN, "View full stats.")
    register_concmd("nobel_clear_stats", "cmd_nobel_clear_stats", ACCESS_ADMIN, "Clear all stats.")
    register_concmd("nobel_start", "cmd_nobel_start", ACCESS_ADMIN, "Start the plugin.")
    register_concmd("nobel_serverstart", "cmd_nobel_serverstart", ACCESS_ADMIN, "")
    register_concmd("nobel_stop", "cmd_nobel_stop", ACCESS_ADMIN, "Stop the plugin.")
    register_concmd("nobel_flash", "cmd_nobel_flash", ACCESS_ADMIN, "Toggle team flash dampening")
    register_concmd("nobel_knife", "cmd_nobel_knife", ACCESS_ADMIN, "Toggle the knife functionality.")
    register_concmd("nobel_knife_now", "cmd_nobel_knife_now", ACCESS_ADMIN, "Toggle the knife functionality NOW.")
    register_concmd("nobel_flashprotection", "cmd_nobel_flashprotection", ACCESS_ADMIN, "Toggle flash protection")

//    register_concmd("nobel_fake_pausemenu", "cmd_nobel_fake_pausemenu", ACCESS_ADMIN, "Fakes the pause menu.")
//    register_concmd("nobel_fake_teamswitch", "switch_teams", ACCESS_ADMIN, "Force team switch")
    create_menus()

    // Find map type
    new mapName[64]
    get_mapname(mapName, charsmax(mapName))
    if (equali(mapName, "de_", 3)) {
        map_type = MAP_TYPE_DE
    } else if (equali(mapName, "cs_", 3)) {
        map_type = MAP_TYPE_CS
    } else if (equali(mapName, "fy_", 3)) {
        map_type = MAP_TYPE_FY
    } else if (equali(mapName, "as_", 3)) {
        map_type = MAP_TYPE_AS
    } else if (equali(mapName, "aim_", 4)) {
        map_type = MAP_TYPE_AIM
    } else if (equali(mapName, "awp_", 4)) {
        map_type = MAP_TYPE_AWP
    }

    log_amx("Map type: %s", map_type)

    // Read configuration values from config/nobel.cfg
    register_cvar("nobel_server_host", "localhost")
    register_cvar("nobel_server_port", "1337")
    register_cvar("nobel_db_host", "localhost")
    register_cvar("nobel_db_user", "root")
    register_cvar("nobel_db_pass", "root")
    register_cvar("nobel_db_database", "beer_cs")
    register_cvar("nobel_num_shield", "2")
    register_cvar("nobel_num_weed", "3")

    map_time_half = ((get_cvar_num("mp_timelimit") * 60) / 2)

    new configdir[128]
    get_configsdir(configdir, charsmax(configdir))
    log_amx("Reading config: %s/nobel.cfg", configdir)
    server_cmd("exec %s/nobel.cfg", configdir)
    server_exec()

    get_cvar_string("nobel_server_host", nobel_server_host, charsmax(nobel_server_host))
    nobel_server_port = get_cvar_num("nobel_server_port")

    new nobel_db_host[50]
    get_cvar_string("nobel_db_host", nobel_db_host, charsmax(nobel_db_host))

    new nobel_db_user[50]
    get_cvar_string("nobel_db_user", nobel_db_user, charsmax(nobel_db_user))

    new nobel_db_pass[50]
    get_cvar_string("nobel_db_pass", nobel_db_pass, charsmax(nobel_db_pass))

    new nobel_db_database[50]
    get_cvar_string("nobel_db_database", nobel_db_database, charsmax(nobel_db_database))

    log_amx("Config: nobel_server_host=%s", nobel_server_host)
    log_amx("Config: nobel_server_port=%d", nobel_server_port)
    log_amx("Config: nobel_db_host=%s", nobel_db_host)
    log_amx("Config: nobel_db_user=%s", nobel_db_user)
    log_amx("Config: nobel_db_pass=%s", nobel_db_pass)
    log_amx("Config: nobel_db_database=%s", nobel_db_database)

    // initialize DB conn
    db = SQL_MakeDbTuple(nobel_db_host, nobel_db_user, nobel_db_pass, nobel_db_database)

    log_amx("Nobel Beer CS plugin loaded!")

    send_event_always("mapchange", mapName)

    new db_error[512]
    new ErrorCode,Handle:SqlConnection = SQL_Connect(db,ErrorCode,db_error,511)
    if(SqlConnection == Empty_Handle) {
        db_available=false
    }

    screen_fade_msg = get_user_msgid("ScreenFade")

    if (retrieve_data_int(VAULT_KEY_MAPEND) == 1) {
        log_amx("Starting timer for notifying pause end")
        set_task(map_pause_time, "mapend_pause_end", 4132, "", 0, "a", 1)
	}
}

public plugin_end() {
	close_vault()
}

public open_vault() {
    if (!vault) {
        vault = nvault_open(VAULT_NAME)
        if (vault == INVALID_HANDLE) {
            log_amx("Failed to open vault: %s", VAULT_NAME)
            return 0
        }
    }
    log_amx("Successfully opened vault: %s", VAULT_NAME)
    return 1
}

public close_vault() {
    if (vault) {
        nvault_close(vault)
    }
}

public save_data(const key[], const value[])
{
    if (!open_vault())
        return -1

    nvault_set(vault, key, value)
    return 0
}

public retrieve_data_int(const key[])
{
    if (!open_vault())
        return -1

    return nvault_get(vault, key)
}

public retrieve_data_string(const key[], const out[], size)
{
    if (!open_vault())
        return -1

    nvault_get(vault, key, out, size)
    return 0
}

public is_map_type(type[])
{
    return equal(map_type, type)
}

public client_command()
{
    new cmd[100]
    read_argv(0, cmd, 100)

    if (equal(cmd, "pauseAck")) {
        is_paused = !is_paused
        log_amx("Changed pause state to: %s", (is_paused ? "true" : "false"))

        if (!PAUSE)
            return PLUGIN_CONTINUE

        if (is_paused) {
            show_pause_menu()
        } else {
            hide_pause_menu()
        }
    }

    return PLUGIN_CONTINUE
}

public show_pause_menu()
{
    new players[32] 
    new playerCount, i 
    get_players(players, playerCount, "c") 
    for (i=0; i<playerCount; i++)
    {
        if (is_user_admin(players[i]))
            menu_display(players[i], pauseMenu, 0)
    }
}

public hide_pause_menu()
{
    new players[32] 
    new playerCount, i 
    get_players(players, playerCount, "c") 
    for (i=0; i<playerCount; i++)
    {
        if (is_user_admin(players[i]))
            show_menu(players[i], 0, " ", 0)
    }
}

public set_state(new_state[])
{
    log_amx("Changing mod state from %s to %s", mod_state, new_state)
    copy(mod_state, charsmax(mod_state), new_state)
}

public in_state(check_state[])
{
    return equal(mod_state, check_state)
}

public message_textmsg(MsgId, MsgDest, MsgEntity) 
{ 
    static msg[50] 
    get_msg_arg_string(2, msg, charsmax(msg))

    if (equal(msg, "#Target_Saved")) {
        time_elapsed = true
    }
}  

public map_change()
{
    if (ENABLED) {
        save_data(VAULT_KEY_MAPEND, "1")
        send_event("mapend")
    }
    return PLUGIN_CONTINUE
}

public mapend_pause_end()
{
    save_data(VAULT_KEY_MAPEND, "0")
    if (in_state(MOD_STATE_STOPPED)) {
        log_amx("mapend_pause_end timer elapsed while mod not started, sending event")
        send_event_always("mapend_pause_end")
    } else {
        log_amx("mapend_pause_end timer elapsed, but mod already started, so skipping event")
    }
}

public weapon_idle_flashbang(id)
{
    if (FLASH && !flash_thrown)
    {
        flash_thrown = true
//        client_cmd(0, "+attack")
//        client_cmd(0, "wait")
        client_cmd(0, "-attack")
    }
}
public hostage_touched() {
    if (!ENABLED)
        return

    if (first_hostage_touched)
        return

    log_amx("touched hostage")
    first_hostage_touched = true
    send_event("hostagefollow")
}

public hostage_traceattack(ent, attacker) {
    return ENABLED ? HAM_SUPERCEDE : HAM_IGNORED
}

public hostage_damage(victim, inflictor, attacker) {
    return ENABLED ? HAM_SUPERCEDE : HAM_IGNORED
}

public hostages_rescued() {
    if (!ENABLED)
        return

    send_event("hostagesrescued")
}

public event_screenfade(id) {
    if (!flash_protection_active)
        return 

    new Float:gametime = get_gametime()

    message_begin(MSG_ONE, screen_fade_msg, {0,0,0}, id)
    write_short(3<<12) // duration
    write_short(1<<6) // hold time
    write_short(0) // flags
    write_byte(random(255)) // r
    write_byte(random(255)) // g
    write_byte(random(255)) // b
    write_byte(235) // a
    message_end()

    client_print(0, print_console, "Flash time %s", gametime)
}

public event_new_round() {

    log_amx("CS event: new_round");
    if (!ENABLED)
        return

    log_amx("CS event: new_round (mod ENABLED)");
    remove_task(7748)
    freezetime = true
}

public event_round_start() {

    log_amx("CS event: round_start");
    if (!ENABLED)
        return

    log_amx("CS event: round_start (mod ENABLED)");
    freezetime = false
    defused = false
    exploded = false
    time_elapsed = false

    if (FLASH)
    {
        flash_thrown = false
        client_cmd(0, "use weapon_flashbang")
    }

    new params[1]
    params[0] = 0
    set_task(8.0, "shieldforce_or_weed_timeout", 3233, params, 0, "a", 1)

    new Float:roundending_timeout = (round_time - 19.0)
    log_amx("roundending timeout set. Value=%f", roundending_timeout)

    set_task(roundending_timeout, "roundending", 6681, params, 0, "a", 1)

    if (FLASHPROTECTION) {
        flash_protection_active = true
        set_task(flash_protection_time, "stop_flash_protection", 9001, params, 0, "a", 1)
    }
}

public stop_flash_protection() {
	remove_task(9001)
	log_amx("Flash protection over")
	flash_protection_active = false
}

public shieldforce_or_weed_timeout() {
    if (!ENABLED)
        return

    new nobel_num_shield = get_cvar_num("nobel_num_shield")
    new nobel_num_weed = get_cvar_num("nobel_num_weed")

    new players[32]
    new playerCount, i
    get_players(players, playerCount, "c")
    new shield_t = 0, shield_ct = 0, smoke_t = 0, smoke_ct = 0
    new CsTeams:team
    for (i=0; i<playerCount; i++)
    {
        team = cs_get_user_team(players[i])
        if (team == CS_TEAM_T) 
        {
            shield_t += cs_get_user_shield(players[i])
            smoke_t += user_has_weapon(players[i], CSW_SMOKEGRENADE)
        }
        else if (team == CS_TEAM_CT)
        {
            shield_ct += cs_get_user_shield(players[i])
            smoke_ct += user_has_weapon(players[i], CSW_SMOKEGRENADE)
        }
    }

    if (shield_t >= nobel_num_shield || shield_ct >= nobel_num_shield)
    {
        send_event("shieldforce")
    }
    else if (smoke_t >= nobel_num_weed || smoke_ct >= nobel_num_weed)
    {
        send_event("weed")
    }
}

public roundending() {
    if (!ENABLED)
        return

    if (!defused) {
        send_event("roundending")
    }
}

public team_win() {
    if (!ENABLED)
        return

    remove_task(6681)

    new players[32]
    new playerCount

    get_players(players, playerCount, "ace", "TERRORIST")
    new bool:t_eliminated = (playerCount == 0)

    get_players(players, playerCount, "ace", "CT")
    new bool:ct_eliminated = (playerCount == 0)

    if (exploded || ct_eliminated) {
        win_count_t++
        win_count_ct = 0
    } else if (defused || t_eliminated || time_elapsed) {
        win_count_t = 0
        win_count_ct++
    }

    if (win_count_t >= 4 || win_count_ct >= 4) {
        send_event("winstreak")
    }
}

public bomb_defused() {
    if (!ENABLED)
        return
    remove_task(7748)
    defused = true
    send_event("bombdefused")
}

public bomb_planted_custom() {
    if (!ENABLED)
        return
    new params[1]
    params[0] = 0
    remove_task(6681)
    set_task(25.0, "bomb_planted_timeout", 7748, params, 0, "a", 1)
    send_event("bombplanted")
}

public bomb_planted_timeout() {
    if (!ENABLED)
        return
    if (!defused) {
        send_event("hurryup")
    }
}

public bomb_explode_custom(planter, defuser) {
    if (!ENABLED)
        return
    exploded = true
    remove_task(7748)
    send_event("bombexploded")
}

public grenade_throw(id, gindex, weaponid) {
    if (ENABLED && weaponid == CSW_FLASHBANG)
    {
        new player[64]
        get_user_name(id, player, 63)
        client_print(0, print_chat, "%s: TIIIIM FLAAAASH", player)
    }
}

public periodic_timer() {
    if (!ENABLED)
        return

    client_cmd(0, "volume 0");

    if (!teams_switched && get_timeleft() < map_time_half) {
        switch_teams()
    }
}

public switch_teams() {
    if (!ENABLED)
        return

    teams_switched = true

    log_amx("Flipping teams")
    send_event("teamswitch")        

    new players[32] 
    new playerCount, i 
    new firstCTplayer = -1
    get_players(players, playerCount, "c") 

    for (i = 0; i < playerCount; i++) {
        new playerName[64]
        cs_set_user_vip(players[i], 0, 0 ,0)
        cs_set_user_vip(players[i], 0, 0, 1)
        get_user_name(players[i], playerName, charsmax(playerName))
        new CsTeams:teamid = cs_get_user_team(players[i])
        if (teamid == CS_TEAM_T)
        {
            log_amx("Putting %s on team CT", playerName)
            cs_set_user_team(players[i], CS_TEAM_CT)
            firstCTplayer = players[i]
        } 
        else if (teamid == CS_TEAM_CT) 
        {
            log_amx("Putting %s on team T", playerName)
            cs_set_user_team(players[i], CS_TEAM_T)
        }
        if (user_has_weapon(players[i], CSW_C4)) {
            engclient_cmd(players[i], "drop", "weapon_c4")
        }
    }
    if (is_map_type(MAP_TYPE_AS) && firstCTplayer >= 0) {
        cs_set_user_vip(firstCTplayer, 1, 1, 1)
    }
    if (is_map_type(MAP_TYPE_AS) && firstCTplayer >= 0) {
        new playerName[64]
        get_user_name(firstCTplayer, playerName, charsmax(playerName))
        log_amx("Setting VIP status on %s", playerName)
        cs_set_user_vip(firstCTplayer, 1, 1, 1)
    }
}

stock db_update(playerid, steamid[], name[], kills, tks, knifed, got_knifed, sips, rounds = 0)
{
    cache_sips[playerid] += sips

    if (!db_available) {
        log_amx("No connection to database!")
        return
    }

    new buf_stor_nok[1024]
    format(buf_stor_nok, 511, "INSERT INTO stats (steamid, name, kills, tks, knifed, got_knifed, sips, rounds) values ('%s', '%s', %d, %d, %d, %d, %d, %d) ON DUPLICATE KEY UPDATE name='%s', kills=kills+%d, tks=tks+%d, knifed=knifed+%d, got_knifed=got_knifed+%d, sips=sips+%d, rounds=rounds+%d", steamid, name, kills, tks, knifed, got_knifed, sips, rounds, name, kills, tks, knifed, got_knifed, sips, rounds)

    log_amx("SQL QUERY: %s", buf_stor_nok)

    SQL_ThreadQuery(db, "db_update_handler", buf_stor_nok)
}

public db_update_handler(FailState,Handle:Query,Error[],Errcode,Data[],DataSize) {
    
//    log_amx("FailState=%d", FailState)
//    log_amx("Errcode=%d", Errcode)
//    log_amx("DataSize=%d", DataSize)
//    log_amx("Query=%s", Query)
//    log_amx("Error=%s", Error)
//    log_amx("Data=%s", Data)
}

public db_clear_stats_handler(FailState,Handle:Query,Error[],Errcode,Data[],DataSize) {
    client_print(0, print_console, "Stats cleared!")
}

public db_stats_handler(FailState,Handle:Query,Error[],Errcode,Data[],DataSize) {
    if (!db_available || !ENABLED)
        return
    client_print(0, print_console, "====== NOBEL STATS ======")
    while (SQL_MoreResults(Query))
    {
        new name[64]
        new steamid[32]
        SQL_ReadResult(Query, 1, name, charsmax(name))
        SQL_ReadResult(Query, 0, steamid, charsmax(steamid))

//        client_print(0, print_console, "%s %s: %d", steamid, name, SQL_ReadResult(Query,2))
        client_print(0, print_console, "%s: %d", name, SQL_ReadResult(Query,2))

        SQL_NextRow(Query)
    }
    client_print(0, print_console, "=====================")
}

public db_full_stats_handler(FailState,Handle:Query,Error[],Errcode,Data[],DataSize) {
    if (!db_available || !ENABLED)
        return
    client_print(0, print_console, "====== NOBEL STATS ======")
    while (SQL_MoreResults(Query))
    {
        new name[64]
        new steamid[32]
        SQL_ReadResult(Query, 1, name, charsmax(name))
        SQL_ReadResult(Query, 0, steamid, charsmax(steamid))

        client_print(0, print_console, "--- %s ---", name)
        client_print(0, print_console, "STEAM ID: %s", steamid)
        client_print(0, print_console, "KILLS: %d", SQL_ReadResult(Query, 2))
        client_print(0, print_console, "TEAM KILLS: %d", SQL_ReadResult(Query, 3))
        client_print(0, print_console, "KNIFED: %d", SQL_ReadResult(Query, 4))
        client_print(0, print_console, "GOT KNIFED: %d", SQL_ReadResult(Query, 5))
        client_print(0, print_console, "SIPS: %d", SQL_ReadResult(Query, 6))
        client_print(0, print_console, "ROUNDS: %d", SQL_ReadResult(Query, 7))
        client_print(0, print_console, " ")

        SQL_NextRow(Query)
    }
    client_print(0, print_console, "=====================")
}

public create_menus()
{
    pauseMenu = menu_create("ADMIN PAUSE MENU", "pause_menu_handler")

    new i
    for (i = 0; i < 9; i++) 
    {
       menu_addblank2(pauseMenu)
    }
//    menu_additem(pauseMenu, "Close menu", "1", 0)
    menu_additem(pauseMenu, "Unpause", "1", 0)
    menu_setprop(pauseMenu, MPROP_PERPAGE, 0)
}

public pause_menu_handler(id, menu, item)
{
    if (item == 9)
    {
        unpause_game()
    }
//    else if (item == 8)
//    {
//        show_menu(id, 0, " ", 0)
//    }
    return PLUGIN_HANDLED;
}

public pause_game()
{
    if (!is_paused)
    {
        log_amx("Pausing game")
        server_cmd("amx_pause")
        server_exec()
    }
}

public unpause_game()
{
    if (is_paused)
    {
        client_print(0, print_chat, "Go go go!")
        send_event("unpause")
        log_amx("Unpausing game")
        server_cmd("amx_pause")
        server_exec()
    }
}

public hook_death()
{
    if (!ENABLED)
        return

    fix_sip_count()

    new killer = read_data(1)
    new victim = read_data(2)
    new headshot = read_data(3)
    new killername[64]
    new victimname[64]
    new killersteamid[64]
    new victimsteamid[64]
    new weapon[32]
    new playAlone = false
    read_data(4, weapon, 31)
    new knifed = !strcmp(weapon, "knife")
    new grenade = !strcmp(weapon, "grenade")
    new suicide = killer == victim || killer == 0

    if (victim == 0)
        return

    new CsTeams:victimteam = cs_get_user_team(victim)
    get_user_name(victim, victimname, 63)
    get_user_authid(victim, victimsteamid, charsmax(victimsteamid))

    new CsTeams:killerteam
    new team_kill = false
    new worstplayer = false
    new players[32]
    new playerCount, i

    if (killer != 0) {
        killerteam = cs_get_user_team(killer)
        get_user_name(killer, killername, 63)
        team_kill = killer != victim && killerteam == victimteam
        get_user_authid(killer, killersteamid, charsmax(killersteamid))
   
        // Find out if the user is the worst on the team
        new killerfrags = get_user_frags(killer)
        get_players(players, playerCount, "ce", killerteam == CS_TEAM_T ? "TERRORIST" : "CT")
        if (playerCount >= 2 && round_count > 3) {
            worstplayer = true
            for (i=0; i<playerCount; i++)
            {
                if (players[i] != killer && killerfrags > get_user_frags(players[i]))
                {
                    worstplayer = false
                }
            }
        }
    }

    log_amx("Death event occurred. Killer: %s, Victim: %s", killername, victimname)

    // UPDATE STATS
    if (suicide)
    {
        db_update(victim, victimsteamid, victimname, 0, 0, 0, 0, 10)
    }
    else if (team_kill)
    {
        db_update(killer, killersteamid, killername, 0, 1, 0, 0, 10)
        db_update(victim, victimsteamid, victimname, 1, 0, 0, 0, 1)
    }
    else
    {
        db_update(killer, killersteamid, killername, 1, 0, 0, 0, 2)
        db_update(victim, victimsteamid, victimname, 0, 0, 0, 0, 1)
    }

    if (knifed && !KNIFE)
    {
        db_update(killer, killersteamid, killername, 0, 0, 1, 0, 0)
        db_update(victim, victimsteamid, victimname, 0, 0, 0, 1, 0)
    }

    // EVENT CONTROL
    if (suicide)
    {
        send_event("suicide")
        if (PAUSE)
        {
            pause_game()
        }
    }
    else if (team_kill)
    {
        send_event("tk", killername, victimname)
        client_print(0, print_chat, "Bottoms up, %s!", killername)
        pause_or_freeze_player(killer)
    }
    else if (KNIFE && !knifed && !grenade)
    {
        // In knife rounds we do NOT accept to be killed by a gun!
        send_event("kniferound", killername)
        client_print(0, print_chat, "Bottoms up, %s!", killername)
        pause_or_freeze_player(killer)
    }
    else if (knifed && !KNIFE)
    {
        send_event("knife", killername, victimname)
        client_print(0, print_chat, "%s got KNIFED!", victimname)
        pause_or_freeze_player(killer)
    }
    else if (grenade)
    {
        send_event("grenade")
        freeze_player(killer)
    }
    else if (headshot)
    {
        playAlone = true
        send_event(worstplayer ? "worstplayer" : "headshot")
        freeze_player(killer)
    }
    else
    {
        playAlone = true
        send_event(worstplayer ? "worstplayer" : "kill")
        freeze_player(killer)
    }

    if (playAlone) {
        get_players(players, playerCount, "c")
        if (playerCount >= 3) {
            new players_t = 0, players_ct = 0
            for (i=0; i<playerCount; i++)
            {
                if (is_user_alive(players[i])) {
                    new CsTeams:playerteam = cs_get_user_team(players[i])
                    if (playerteam == CS_TEAM_T) {
                        players_t++;
                    } else if (playerteam == CS_TEAM_CT) {
                        players_ct++;
                    }
                }
            }

            if (!alone_round && (players_t == 1 || players_ct == 1)) {
                alone_round = true
                send_event("alone")
            }
        }
    }
}

public pause_or_freeze_player(killer)
{
    if (PAUSE)
    {
        pause_game()
    }
    else
    {
        freeze_player(killer)
        // Ensure that the server does not show the pause images
        send_event("unpause")
    }
}

public fix_sip_count()
{
    if (ENABLED)
    {
        // Re-update the latency column in scoreboard
        new players[32] 
        new playerCount, i 
        get_players(players, playerCount, "c") 
        for (i=0; i<playerCount; i++)
        {
            fw_UpdateClientData(players[i])
        }
    }
}

public set_user_speed(id)
{
    if (!ENABLED)
        return

    if (freezetime || cannot_move[id] == true) {
        new user_name[32]
        get_user_name(id, user_name, charsmax(user_name))
        log_amx("Freezing player due to freezetime or by kill: %s, freezetime: %i, cannot_move[%i]: %i", user_name, freezetime, id, cannot_move[id])
        set_user_maxspeed(id, 0.1)
    }
    else {
        new Float:speed
        static clip, ammo
        new weaponId = get_user_weapon(id, clip, ammo)
        switch(weaponId) {
            case 
                CSW_SCOUT: {
                    speed = 260.0
                }
            case 
                CSW_KNIFE,
                CSW_GLOCK18,
                CSW_C4,
                CSW_HEGRENADE,
                CSW_MAC10,
                CSW_SMOKEGRENADE,
                CSW_ELITE,
                CSW_FIVESEVEN,
                CSW_UMP45,
                CSW_USP,
                CSW_TMP,
                CSW_FLASHBANG,
                CSW_DEAGLE,
                CSW_P228, 
                CSW_SHIELDGUN,
                CSI_SHIELD,
                CSW_MP5NAVY: {
                    speed = 250.0
                }
            case 
                CSW_P90: {
                    speed = 245.0
                }
            case 
                CSW_XM1014,
                CSW_AUG,
                CSW_GALIL, 
                CSW_FAMAS: {
                    speed = 240.0
                }
            case 
                CSW_SG552: {
                    speed = 235.0
                }
            case 
                 CSW_M3,
                 CSW_M4A1: {
                    speed = 230.0
                }
            case 
                CSW_AK47: {
                    speed = 221.0
                }
            case 
                CSW_M249: {
                    speed = 220.0
                }
            case 
                CSW_G3SG1,
                CSW_SG550,
                CSW_AWP: {
                    speed = 210.0
                }
            default: {
                new user_name[32] 
                get_user_name(id, user_name, charsmax(user_name))
                log_amx("Failed to set user speed for user %s, weapon id: %d", user_name, weaponId)
                speed = 250.0
            }
        }
        set_user_maxspeed(id, speed)
    }
}

public unfreeze_player(params[], id)
{
    if (ENABLED) {
        new player = params[0]
        // unfreeze here
        cannot_move[player] = false
        set_user_speed(player)
        client_print(player, print_chat, "You can now move again.")
    }
}

stock freeze_player(killer)
{
    if (ENABLED) {
        new user_name[32]
        get_user_name(killer, user_name, charsmax(user_name))
        log_amx("Freezing player: %s", user_name)
        set_user_maxspeed(killer, 0.1)
        new params[1]
        params[0] = killer
        cannot_move[killer] = true 

        if (task_exists(killer)) {
            change_task(killer, user_frozen_time)
        } else {
            set_task(user_frozen_time, "unfreeze_player", killer, params, 1, "a", 1)
        }
    }
}

public knife_round_timeout() 
{
    server_cmd("amx_csay green LAAAARJF ROUND !!!!! Knife only!!")
    server_cmd("amx_csay red LAAAARJF ROUND !!!!! Knife only!!")
    server_cmd("amx_csay blue LAAAARJF ROUND !!!!! Knife only!!")
    server_cmd("amx_csay red FAT DET !!!")
    server_exec()
}

public round_start() 
{ 
    if (!ENABLED)
        return

    remove_task(6681)

    if (knife_next)
        KNIFE = true
    
    if (knife_last)
        disable_knife_round()

    if (KNIFE)
    {
        new params[1]
        params[0] = 0
        set_task(1.0, "knife_round_timeout", 1691, params, 0, "a", 1)
    }

    round_count++
    alone_round = false
    first_hostage_touched = false

    new players[32] 
    new playerCount, i 
    get_players(players, playerCount, "c") 
    for (i=0; i<playerCount; i++)
    {
        player_money[i] = cs_get_user_money(players[i])

        new CsTeams:teamid = cs_get_user_team(players[i])
        if (teamid == CS_TEAM_T || teamid == CS_TEAM_CT)
        {
            new steamid[32]
            new name[64]
            get_user_name(players[i], name, charsmax(name))
            get_user_authid(players[i], steamid, charsmax(steamid))
            db_update(players[i], steamid, name, 0, 0, 0, 0, 1, 1)
            cannot_move[players[i]] = false
        }
    }

    if (KNIFE) {
        send_event("leif")
    } else {
        send_event(round_count == 1 ? "firstround" : "round")
    }

    new params[1]
    params[0] = 0
    set_task(8.0, "money_timeout", 5591, params, 0, "a", 1)
}

public money_timeout()
{
    new bool:any = false
    new players[32] 
    new playerCount, i 
    get_players(players, playerCount, "c") 
    for (i=0; i<playerCount; i++)
    {
        new current_money = cs_get_user_money(players[i])
        if ((player_money[i] - current_money) >= 5500) {
            any = true
        }
    }

    if (any)
        send_event("rich")
}

public shuffle_players()
{
    new players[32] 
    new playerCount 
    get_players(players, playerCount, "ach") 
    
    SortCustom1D(players, playerCount, "do_the_shuffle")

    for (new i=0; i < playerCount; i++)
    {
        new playerName[64]
        get_user_name(players[i], playerName, charsmax(playerName))
        if (i%2 == 1) {
            log_amx("Putting %s on team T", playerName)
            cs_set_user_team(players[i], CS_TEAM_T)
        } else {
            log_amx("Putting %s on team CT", playerName)
            cs_set_user_team(players[i], CS_TEAM_CT)
        }
    }
    return PLUGIN_HANDLED
}

public do_the_shuffle(elm1, elm2)
{
    return random_num(0, 1) == 1 ? 1 : -1;
}

public disable_knife_round()
{
    PAUSE = pause_enabled_before_kniferound
    KNIFE = false
    knife_next = false
    knife_last = false
    client_print(0, print_chat, "Nobel LAAAJF ROUND disabled!")

    return PLUGIN_HANDLED;
}

public cmd_nobel_maps(id, level, cid)
{
    if (!cmd_access(id, level, cid, 0))
        return PLUGIN_HANDLED;

    new mapsdir[] = "maps"
    new curfile[MAX_FILENAME_LEN]

    if (!dir_exists(mapsdir)) {
        client_print(id, print_console, "No maps found on server")
        return PLUGIN_HANDLED
    }

    new mapid = 1
    new dh = open_dir(mapsdir, curfile, MAX_FILENAME_LEN - 1)
    while (next_file(dh, curfile, MAX_FILENAME_LEN - 1)) {
        // if (containi(curfile, ".bsp") != -1)
        if (regex_match_simple(curfile, ".bsp$", PCRE_CASELESS) > 0) {
            replace_string(curfile, MAX_FILENAME_LEN - 1, ".bsp", "", false)
            client_print(id, print_console, "%d: %s", mapid++, curfile)
        }
    }
    close_dir(dh) 

    return PLUGIN_HANDLED;
}

public cmd_nobel_knife_now(id, level, cid)
{
    if (!cmd_access(id, level, cid, 0))
        return PLUGIN_HANDLED;

    if (ENABLED)
        disable_knife_round()

    return PLUGIN_HANDLED;
}

public cmd_nobel_knife(id, level, cid)
{
    if (!cmd_access(id, level, cid, 0))
        return PLUGIN_HANDLED;

    if (!ENABLED)
        return PLUGIN_HANDLED;
 
    if (!KNIFE && !knife_next)
    {
        pause_enabled_before_kniferound = PAUSE

        server_cmd("amx_csay green NEXT ROUND IS LAAAARJF ROUND !!!!! Knife only!!")
        server_cmd("amx_csay red NEXT ROUND IS LAAAARJF ROUND !!!!! Knife only!!")
        server_cmd("amx_csay blue NEXT ROUND IS LAAAARJF ROUND !!!!! Knife only!!")
        server_cmd("amx_csay red FAT DET !!!")
        server_exec()
        client_print(0, print_chat, "Nobel LAAAJF ROUND enabled!")
        knife_next = true
    }
    else
    {
        server_cmd("amx_csay green LAST LAAAARJF ROUND !!!!!")
        server_cmd("amx_csay red LAST LAAAARJF ROUND !!!!!")
        server_cmd("amx_csay blue LAST LAAAARJF ROUND !!!!!")
        server_cmd("amx_csay red FAT DET !!!")
        server_exec()
        knife_last = true
    }

    return PLUGIN_HANDLED;
}

public cmd_nobel_flash(id, level, cid)
{
    if (!cmd_access(id, level, cid, 0))
        return PLUGIN_HANDLED;

    if (ENABLED)
    {
        FLASH = !FLASH
        //client_print(0, print_chat, "Nobel TIIIIIM FLASH %s!", (FLASH ? "enabled" : "disabled"))
    }
    return PLUGIN_HANDLED
}

public cmd_nobel_badum(id, level, cid)
{
    if (!cmd_access(id, level, cid, 0))
        return PLUGIN_HANDLED;

    if (ENABLED)
    {
        BADUM = !BADUM
        client_print(0, print_chat, "Nobel Badum %s!", (BADUM ? "enabled" : "disabled"))   
    }
    return PLUGIN_HANDLED
}

public cmd_nobel_theme(id, level, cid)
{
    if (!cmd_access(id, level, cid, 0))
        return PLUGIN_HANDLED;

    new arg[100]
    read_argv(1, arg, 100)
    if (!equali(arg, ""))
    {
        client_print(0, print_chat, "Nobel sound theme changed to: %s!", arg)
        send_event("theme", arg)
    }
    return PLUGIN_HANDLED
}

public cmd_badum(id, level, cid)
{
    if (!cmd_access(id, level, cid, 0))
        return PLUGIN_HANDLED;

    if (BADUM)
        send_event("badum")    
    return PLUGIN_HANDLED;
}

public cmd_ready(id, level, cid)
{
    if (!cmd_access(id, level, cid, 0))
        return PLUGIN_HANDLED;

    if (!ENABLED)
        send_event_always("ready")
    return PLUGIN_HANDLED;
}

public cmd_shutup(id, level, cid)
{
    if (!cmd_access(id, level, cid, 0))
        return PLUGIN_HANDLED;

    send_event_always("shutup")
    return PLUGIN_HANDLED;
}

public player_spawned(id)
{
    if (FLASH && is_user_alive(id))
    {
        give_item(id, "weapon_flashbang")
        give_item(id, "weapon_flashbang")
    }
}

stock send_event(cmd[], name[] = "", name2[] = "")
{
    if (ENABLED && SOUND) {
        send_event_always(cmd, name, name2)
    }
}

stock send_event_always(cmd[], killer[] = "", victim[] = "")
{
    new sock
    new error
    sock = socket_open(nobel_server_host, nobel_server_port, SOCKET_TCP, error)
    if (!error)
    {
        new buf[128]
        if (USE_JSON) {
            format(buf, 128, "{\"event\":\"%s\",\"killer\":\"%s\",\"victim\":\"%s\"}", cmd, killer, victim)
        } else {
            format(buf, 128, "%s|€@!|%s|€@!|%s", cmd, killer, victim)
        }
        new len = strlen(buf)
    
        log_amx("Sending event: %s (%s %s)", cmd, killer, victim)
        socket_send(sock, buf, len)
        socket_close(sock)
    }
}

public cmd_nobel(id, level, cid)
{
    if (!cmd_access(id, level, cid, 0))
        return PLUGIN_HANDLED;

    client_print(id, print_console, "Function    State")
    client_print(id, print_console, "nobel_mod %s", (ENABLED ? "Enabled" : "Disabled"))
    client_print(id, print_console, "nobel_sound %s", (SOUND ? "Enabled" : "Disabled"))
    client_print(id, print_console, "nobel_pause %s", (PAUSE ? "Enabled" : "Disabled"))
    client_print(id, print_console, "nobel_flash %s", (FLASH ? "Enabled" : "Disabled"))
    client_print(id, print_console, "nobel_badum %s", (BADUM ? "Enabled" : "Disabled"))
    client_print(id, print_console, "nobel_knife %s", (KNIFE ? "Enabled" : "Disabled"))
    client_print(id, print_console, "nobel_flashprotection %s", (FLASHPROTECTION ? "Enabled" : "Disabled"))
    return PLUGIN_HANDLED;
}

public cmd_nobel_start(id, level, cid)
{
    if (!cmd_access(id, level, cid, 0) || !in_state(MOD_STATE_STOPPED))
        return PLUGIN_HANDLED;

    round_count = 0
    set_state(MOD_STATE_STARTING)

    // Load map type specific config
    new map_type_cfg[22]
    format(map_type_cfg, 22, "exec nobel_map_%s.cfg", map_type)
    log_amx("Executing: %s", map_type_cfg)
    server_cmd(map_type_cfg)
    server_exec();
    round_time = (get_cvar_float("mp_roundtime") * 60.0)
    log_amx("Read mp_roundtime value=%f", round_time)

    shuffle_players()
    server_cmd("exec mr15.cfg")
    
    new params[1]
    params[0] = 0

    set_task(1.0, "periodic_timer", 1000, params, 0, "a", 2147483647)
    return PLUGIN_HANDLED;
}

public cmd_nobel_serverstart(id, level, cid)
{
    if (!cmd_access(id, level, cid, 0))
        return PLUGIN_HANDLED

    if (ENABLED)
        return PLUGIN_HANDLED

    ENABLED = true
    SOUND = true
    FLASHPROTECTION = true

    if (db_available) {
        cmd_nobel_clear_stats(0, 0, 0)
        PAUSE = true
    }

    round_start()
    set_state(MOD_STATE_STARTED)

    return PLUGIN_HANDLED
}

public cmd_nobel_stop(id, level, cid)
{
    if (!cmd_access(id, level, cid, 0) || !in_state(MOD_STATE_STARTED))
        return PLUGIN_HANDLED;

    ENABLED = false
    remove_task(1000)
    server_cmd("exec stop.cfg")
    client_print(0, print_console, "Nobel Beer CS disabled!")	
    set_state(MOD_STATE_STOPPED)
    return PLUGIN_HANDLED;
}

//public cmd_nobel_fake_pausemenu()
//{
//    pause_game()
//
//    new Players[32] 
//    new playerCount, i 
//    get_players(Players, playerCount, "c") 
//    for (i=0; i<playerCount; i++)
//    {
//        if (is_user_admin(Players[i]))
//        {
//            menu_display(Players[i], pauseMenu, 0)
//        }
//    }
//    return PLUGIN_HANDLED;
//}

public cmd_nobel_pause(id, level, cid)
{
    if (!cmd_access(id, level, cid, 0))
        return PLUGIN_HANDLED;

    PAUSE = !PAUSE
    if (PAUSE)
        client_print(0, print_chat, "Nobel Beer CS pausing enabled")
    else
        client_print(0, print_chat, "Nobel Beer CS pausing disabled")
    return PLUGIN_HANDLED;
}

public cmd_nobel_flashprotection(id, level, cid)
{
    if (!cmd_access(id, level, cid, 0))
        return PLUGIN_HANDLED;

    FLASHPROTECTION = !FLASHPROTECTION
    if (FLASHPROTECTION)
        client_print(0, print_chat, "Nobel Beer CS flash protection enabled")
    else
        client_print(0, print_chat, "Nobel Beer CS flash protection disabled")
    return PLUGIN_HANDLED;
}

public cmd_nobel_sound(id, level, cid)
{
    if (!cmd_access(id, level, cid, 0))
        return PLUGIN_HANDLED;

    SOUND = !SOUND
    if (SOUND)
        client_print(0, print_chat, "Nobel Beer CS sound enabled")
    else
        client_print(0, print_chat, "Nobel Beer CS sound disabled")
    return PLUGIN_HANDLED;
}

public cmd_nobel_clear_stats(id, level, cid)
{
    if (!cmd_access(id, level, cid, 0))
        return PLUGIN_HANDLED;

    client_print(0, print_console, "DB AVAILABLE? %s", (db_available ? "true" : "false"))
    client_print(0, print_console, "Clearing stats.")

    new Players[32] 
    new playerCount, i 
    get_players(Players, playerCount, "c") 

    for (i=0; i<playerCount; i++) {
        cache_sips[Players[i]] = 0
    }

    if (db_available)
    {
        SQL_ThreadQuery(db, "db_clear_stats_handler", "TRUNCATE TABLE stats")
    }    

    send_event("clearstats")    

    return PLUGIN_HANDLED;
} 

public cmd_nobel_stats(id, level, cid)
{
    if (!cmd_access(id, level, cid, 0))
        return PLUGIN_HANDLED;

    if (!db_available)
        return PLUGIN_HANDLED;

    SQL_ThreadQuery(db, "db_stats_handler", "SELECT steamid,name,sips FROM stats ORDER BY sips DESC;")
    return PLUGIN_HANDLED;
}

public cmd_nobel_full_stats(id, level, cid)
{
    if (!cmd_access(id, level, cid, 0))
        return PLUGIN_HANDLED;

    SQL_ThreadQuery(db, "db_full_stats_handler", "SELECT * FROM stats ORDER BY name;")
    return PLUGIN_HANDLED;
}

public fw_UpdateClientData(id)
{
    if (!ENABLED) return;

    // Scoreboard key being pressed?
//    if (!(pev(id, pev_button) & IN_SCORE) && !(pev(id, pev_oldbuttons) & IN_SCORE))
//        return;

    static sending, bits, bits_added
    sending = false
    bits = 0
    bits_added = 0

    new Players[32] 
    new playerCount, i 
    get_players(Players, playerCount, "c") 

    for (i=0; i<playerCount; i++) {

        if (!sending) {
            message_begin(MSG_ONE_UNRELIABLE, SVC_PINGS, _, id)
            sending = true
        }

        AddBits(bits, bits_added, 1, 1) // flag = 1
        AddBits(bits, bits_added, i, 5)
        AddBits(bits, bits_added, cache_sips[Players[i]], 12)
        AddBits(bits, bits_added, 0, 7) // loss

        WriteBytes(bits, bits_added, false)
    }

    if (sending) {
        AddBits(bits, bits_added, 0, 1) // flag = 0
        WriteBytes(bits, bits_added, true)
        message_end()
    }

}

AddBits(&bits, &bits_added, value, bit_count)
{
    // No more room (max 32 bits / 1 cell)
    if (bit_count > (32 - bits_added) || bit_count < 1)
        return;

    // Clamp value if its too high
    if (value >= (1 << bit_count))
        value = ((1 << bit_count) - 1)

    // Add new bits
    bits = bits + (value << bits_added)

    // Increase bits added counter
    bits_added += bit_count

}

WriteBytes(&bits, &bits_added, write_remaining)
{
    // Keep looping if there are more bytes to write
    while (bits_added >= 8) {
        // Write group of 8 bits
        write_byte(bits & ((1 << 8) - 1))

        // Remove bits we just sent by moving all bits to the right 8 times
        bits = bits >> 8
        bits_added -= 8
    }

    // Write remaining bits too?
    if (write_remaining && bits_added > 0) {
        write_byte(bits)
        bits = 0
        bits_added = 0
    }
}

