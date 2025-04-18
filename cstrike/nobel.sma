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
#include <json>

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

new bool:ENABLED = false
new bool:PAUSE = false
new bool:KNIFEPAUSE = false
new bool:SOUND = false
new bool:FLASH = false
new bool:BADUM = false
new bool:KNIFE = false
new bool:ANTIZOOMPISTOL = false
new bool:FLASHPROTECTION = false
new bool:RAMBO = false
new bool:BONG = false

new pauseMenu

new nobel_server_host[50]
new nobel_server_port
new mod_state[10] = MOD_STATE_STOPPED
new bool:knife_next = false
new bool:knife_last = false
new bool:rambo_next = false
new bool:rambo_last = false
new bool:bong_next = false
new bool:bong_last = false
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
new Float:flash_protection_time = 8.0
new Float:map_pause_time = 300.0
new vault
new balance_socket
new bool:tk_cooldown = false

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR)
    register_event("HLTV", "round_start", "a", "1=0", "2=0")
    register_event("HLTV", "event_new_round", "a", "1=0", "2=0")
    register_event("DeathMsg", "hook_death", "a")
    register_event("30", "map_change", "a")
    register_event("TeamInfo", "fix_sip_count", "a")
    register_event("TeamInfo", "player_switched_teams", "a")
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
    RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_awp", "event_zoompistol")
    RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_g3sg1", "event_mildzoompistol")
    RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_sg550", "event_mildzoompistol")

    // Register HAM events for all weapons except m249 (RAMBOOOO)
    new weaponName[32]
    new NOSHOT_BITSUM = (1<<CSW_KNIFE) | (1<<CSW_HEGRENADE) | (1<<CSW_FLASHBANG) | (1<<CSW_SMOKEGRENADE) | (1<<CSW_M249)
    for(new iId = CSW_P228; iId <= CSW_P90; iId++)
    {
        if ( ~NOSHOT_BITSUM & 1<<iId && get_weaponname(iId, weaponName, charsmax(weaponName)) )
        {
            RegisterHam(Ham_Weapon_PrimaryAttack, weaponName, "rambo_slap", 0)
        }
    }

    register_concmd("nobel_maps", "cmd_nobel_maps", ACCESS_PUBLIC, "Lists available maps on the server.")
    register_concmd("nobel_pause", "cmd_nobel_pause", ACCESS_ADMIN, "Disable/enable pause.")
    register_concmd("nobel_knifepause", "cmd_nobel_knifepause", ACCESS_ADMIN, "Disable/enable pausing on knifekills.")
    register_concmd("nobel_sound", "cmd_nobel_sound", ACCESS_ADMIN, "Enable/disable sound.")
    register_concmd("nobel_badum", "cmd_nobel_badum", ACCESS_ADMIN, "Enable/disable badum.")
    register_concmd("nobel_theme", "cmd_nobel_theme", ACCESS_ADMIN, "Change sound theme.")
    register_concmd("badum", "cmd_badum", ACCESS_ADMIN, "Plays badum!")
    register_concmd("shutup", "cmd_shutup", ACCESS_ADMIN, "Plays shutup!")
    register_concmd("ready", "cmd_ready", ACCESS_ADMIN, "Plays reeady sound!")
    register_concmd("nobel", "cmd_nobel", ACCESS_ADMIN, "View current settings.")
    register_concmd("nobel_shuffle", "cmd_nobel_shuffle", ACCESS_ADMIN, "Shuffles all players.")
    register_concmd("nobel_start", "cmd_nobel_start", ACCESS_ADMIN, "Start the plugin.")
    register_concmd("nobel_serverstart", "cmd_nobel_serverstart", ACCESS_ADMIN, "")
    register_concmd("nobel_stop", "cmd_nobel_stop", ACCESS_ADMIN, "Stop the plugin.")
    register_concmd("nobel_flash", "cmd_nobel_flash", ACCESS_ADMIN, "Toggle team flash dampening")
    register_concmd("nobel_knife", "cmd_nobel_knife", ACCESS_ADMIN, "Toggle the knife functionality.")
    register_concmd("nobel_knife_now", "cmd_nobel_knife_now", ACCESS_ADMIN, "Toggle the knife functionality NOW.")
    register_concmd("nobel_rambo", "cmd_nobel_rambo", ACCESS_ADMIN, "Toggle the rambo functionality.")
    register_concmd("nobel_bong", "cmd_nobel_bong", ACCESS_ADMIN, "Toggle bong mode.")
    register_concmd("nobel_balance", "cmd_nobel_balance", ACCESS_ADMIN, "Rebalance teams.")
    register_concmd("nobel_flashprotection", "cmd_nobel_flashprotection", ACCESS_ADMIN, "Toggle flash protection")
    register_concmd("nobel_antizoompistol", "cmd_nobel_antizoompistol", ACCESS_ADMIN, "Toggle zoompistol punishment.")
    register_concmd("nobel_sendplayers", "cmd_nobel_sendplayers", ACCESS_ADMIN, "Sends list of players to webserver")

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
    register_cvar("nobel_num_shield", "2")
    register_cvar("nobel_num_weed", "3")
    register_cvar("nobel_num_kit", "2")

    map_time_half = ((get_cvar_num("mp_timelimit") * 60) / 2)

    new configdir[128]
    get_configsdir(configdir, charsmax(configdir))
    log_amx("Reading config: %s/nobel.cfg", configdir)
    server_cmd("exec %s/nobel.cfg", configdir)
    server_exec()

    get_cvar_string("nobel_server_host", nobel_server_host, charsmax(nobel_server_host))
    nobel_server_port = get_cvar_num("nobel_server_port")

    log_amx("Config: nobel_server_host=%s", nobel_server_host)
    log_amx("Config: nobel_server_port=%d", nobel_server_port)

    log_amx("Nobel Beer CS plugin loaded!")

    send_event_always("mapchange", mapName)

    screen_fade_msg = get_user_msgid("ScreenFade")

    if (retrieve_data_int(VAULT_KEY_MAPEND) == 1) {
        log_amx("Starting timer for notifying pause end")
        set_task(map_pause_time, "mapend_pause_end", 4132, "", 0, "a", 1)
    }
}

public remove_cooldown() {
    tk_cooldown = false
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

    message_begin(MSG_ONE, screen_fade_msg, {0,0,0}, id)
    write_short(3<<12) // duration
    write_short(1<<6) // hold time
    write_short(0) // flags
    write_byte(random(255)) // r
    write_byte(random(255)) // g
    write_byte(random(255)) // b
    write_byte(235) // a
    message_end()
}

public event_new_round() {

    if (!ENABLED) {
        log_amx("CS event: new_round (mod DISABLED)");
        return
    }

    new players[32]
    new playerCount, i
    get_players(players, playerCount, "c") 
    for (i=0; i<playerCount; i++) {
        if (task_exists(players[i]+100)) {
            log_amx("Removing rambo task for id %d (%d)", players[i], players[i]+100)
            remove_task(players[i]+100)
        }
    }
    client_cmd(0, "-attack") 

    log_amx("CS event: new_round (mod ENABLED)");
    remove_task(7748)
    freezetime = true
}

public event_zoompistol(id) {
    if (!ANTIZOOMPISTOL)
        return HAM_IGNORED
    new owner_id = pev(id, pev_owner)
    new owner_name[63]
    get_user_name(owner_id, owner_name, 63)
    client_print(0, print_chat, "%s bruger zoompistol!1!!", owner_name)

    new tmp_param[1]
    tmp_param[0] = owner_id
    set_task(0.1, "zoomslap", 9191, tmp_param, sizeof(tmp_param))

    return HAM_HANDLED
}

public event_mildzoompistol(id) {
    if (!ANTIZOOMPISTOL)
        return HAM_IGNORED
    new owner_id = pev(id, pev_owner)
    new owner_name[63]
    get_user_name(owner_id, owner_name, 63)
    client_print(0, print_chat, "%s bruger (mild) zoompistol!1!!", owner_name)

    new tmp_param[1]
    tmp_param[0] = owner_id
    set_task(0.1, "zoomslap_mild", 9191, tmp_param, sizeof(tmp_param))

    return HAM_HANDLED
}

public zoomslap_mild(const params[], id) {
    new player = params[0]
    user_slap(player, random_num(10, 45), 1)
}

public zoomslap(const params[], id) {
    new player = params[0]
    user_slap(player, random_num(17, 85), 1)
}

public event_round_start() {
    log_amx("CS event: round_start");
    send_players()
    if (!ENABLED)
        return

    send_event("roundstart")
    log_amx("CS event: round_start (mod ENABLED)");
    freezetime = false
    defused = false
    exploded = false
    time_elapsed = false

    new mapName[64]
    get_mapname(mapName, charsmax(mapName))
    if (equali(mapName, "de_rats")) {
        send_event("rats")
    }

    if (FLASH)
    {
        flash_thrown = false
        client_cmd(0, "use weapon_flashbang")
    }
    if (!RAMBO)
    {
        remove_task(1692)
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
    log_amx("Technoflash period ended")
    flash_protection_active = false
}

public shieldforce_or_weed_timeout() {
    if (!ENABLED)
        return

    new nobel_num_shield = get_cvar_num("nobel_num_shield")
    new nobel_num_weed = get_cvar_num("nobel_num_weed")
    new nobel_num_kit = get_cvar_num("nobel_num_kit")

    new players[32]
    new playerCount, i
    get_players(players, playerCount, "c")
    new shield_t = 0, shield_ct = 0, smoke_t = 0, smoke_ct = 0, kit_t = 0, kit_ct = 0
    new CsTeams:team
    for (i=0; i<playerCount; i++)
    {
        team = cs_get_user_team(players[i])
        if (team == CS_TEAM_T) 
        {
            shield_t += cs_get_user_shield(players[i])
            smoke_t += user_has_weapon(players[i], CSW_SMOKEGRENADE)
            kit_t += cs_get_user_defuse(players[i])
        }
        else if (team == CS_TEAM_CT)
        {
            shield_ct += cs_get_user_shield(players[i])
            smoke_ct += user_has_weapon(players[i], CSW_SMOKEGRENADE)
            kit_ct += cs_get_user_defuse(players[i])
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
    if (kit_t >= nobel_num_kit || kit_ct >= nobel_num_kit)
    {
        set_task(3.0, "event_kidd")
    }
}

public event_kidd() {
    send_event("kidd")
    client_print(0, print_chat, "Kiiiiiidd!")
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
        client_print(0, print_chat, "%s: TIM FLAAAASH", player)
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

    if (RAMBO) {
        log_amx("Removing rambo task for id %d (%d)", victim, victim+100)
        remove_task(victim+100)
    }

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

    // EVENT CONTROL
    if (suicide)
    {
        if (BONG) {
            send_event("bong", killersteamid, victimsteamid)
            client_print(0, print_chat, "%s? drikdrikdrikdrikdrikdrikdrikdrik", killername)
        } else {
            send_event("suicide", victimsteamid)
            client_print(0, print_chat, "Hehe, %s begik selvmord :>", killername)
        }
        if (PAUSE) {
            pause_game()
        }
    }
    else if (team_kill)
    {
        new steamid[64]
        get_user_authid(killer, steamid, charsmax(steamid))

        log_amx("tk_cooldown = true%s", tk_cooldown)
        set_task(0.1, "remove_cooldown", 11699, "", 0, "a", 0)

        if (BONG) {
            send_event("bong", killersteamid, victimsteamid)
            client_print(0, print_chat, "%s? drikdrikdrikdrikdrikdrikdrikdrik", killername)
        } else if (equali(steamid, "STEAM_0:1:13218758") || equali(steamid, "STEAM_0:1:156056572") || equali(steamid, "STEAM_0:0:161232090")) {
            send_event("mikkitk", killersteamid, victimsteamid)
            client_print(0, print_chat, "Business as usual")
        } else {
            send_event("tk", killersteamid, victimsteamid)
            client_print(0, print_chat, "Kan du bunde, %s?", killername)
        }

        if (tk_cooldown != true) {
            pause_or_freeze_player(killer)
            tk_cooldown = true
        }
    }
    else if (KNIFE && !knifed && !grenade)
    {
        // In knife rounds we do NOT accept to be killed by a gun!
        send_event("kniferound", killersteamid)
        client_print(0, print_chat, "Bottoms up, %s!", killername)
        pause_or_freeze_player(killer)
    }
    else if (knifed && !KNIFE)
    {
        // If Jeppe knifed someone
        new steamid[64]
        get_user_authid(killer, steamid, charsmax(steamid))
        if (equali(steamid, "STEAM_0:0:32762533")) {
            client_print(0, print_chat, "Hvad fanden Jeppe, hvad laver du der?!")
            send_event("jeppeknife", killersteamid, victimsteamid)
        } else if (equali(steamid, "STEAM_0:1:14846448")) {
            client_print(0, print_chat, "Thue, DET ER RIGTIGT")
            send_event("thueknife", killersteamid, victimsteamid)
        } else if (equali(steamid, "STEAM_0:1:34134896")) {
            client_print(0, print_chat, "Emil har en gennemsnitlig penis.")
            send_event("emilknife", killersteamid, victimsteamid)
        } else if (equali(steamid, "STEAM_0:1:39235412")) {
            client_print(0, print_chat, "CHRIS DOLKER")
            send_event("chrisknife", killersteamid, victimsteamid)
        } else if (equali(steamid, "STEAM_0:1:575443358")) {
            client_print(0, print_chat, "Knifed af Jeameppe.. Pinligt!")
            send_event("jeameppeknife", killersteamid, victimsteamid)
        } else if (equali(steamid, "STEAM_0:1:11318024")) {
            client_print(0, print_chat, "BOOOB HAN KNEPPER")
            send_event("bobknife", killersteamid, victimsteamid)
        } else if (equali(steamid, "STEAM_0:0:46546093")) {
            client_print(0, print_chat, "Here's Johnny!")
            send_event("aminknife", killersteamid, victimsteamid)
        } else if (equali(steamid, "STEAM_0:0:29158958")) {
            client_print(0, print_chat, "Bernth tried to knife you. KILL HIM")
            send_event("bernthknife", killersteamid, victimsteamid)
        } else {
            send_event("knife", killersteamid, victimsteamid)
            client_print(0, print_chat, "%s got KNIFED!", victimname)
        }

        if (KNIFEPAUSE) {
            pause_or_freeze_player(killer)
        }
    }
    else if (grenade)
    {
        send_event("grenade", killersteamid, victimsteamid)
        freeze_player(killer)
    }
    else if (headshot)
    {
        playAlone = true
        if (worstplayer)
            send_event("worstplayer")
        send_event("headshot", killersteamid, victimsteamid)
        freeze_player(killer)
    }
    else
    {
        playAlone = true
        if (worstplayer)
            send_event("worstplayer")
        send_event("kill", killersteamid, victimsteamid)
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

    if (RAMBO) {
        new weaponId = get_user_weapon(id)
        if (weaponId == CSW_M249) {
            client_cmd(id, "+attack") 
        } else {
            client_cmd(id, "-attack")
        }
    }

    if (freezetime || cannot_move[id] == true) {
        new user_name[32]
        get_user_name(id, user_name, charsmax(user_name))
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

public bong_round_timeout() 
{
    server_cmd("amx_csay green PAS PÅ!!")
    server_cmd("amx_csay red DER ER BONG I LUFTEN")
    server_cmd("amx_csay blue drikdrikdrikdrikdrikdrikdrikdrik")
    server_exec()
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

    if (rambo_next)
        RAMBO = true
    
    if (rambo_last)
        disable_rambo_round()

    if (bong_next)
        BONG = true
    
    if (bong_last)
        disable_bong_round()

    if (RAMBO)
    {
        new params[1]
        params[0] = 0
        set_task(1.0, "rambo_round_timeout", 1692, params, 0, "a", 1)
    }
    
    if (KNIFE)
    {
        new params[1]
        params[0] = 0
        set_task(1.0, "knife_round_timeout", 1691, params, 0, "a", 1)
    }

    if (BONG)
    {
        new params[1]
        params[0] = 0
        set_task(1.0, "bong_round_timeout", 1693, params, 0, "a", 1)
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
            cannot_move[players[i]] = false
        }
    }

    if (KNIFE) {
        send_event("leif")
    } else if (RAMBO) {
        send_event("rambo")
    } else if (BONG) {
        send_event("bongintro")
    } else {
        send_event(round_count == 1 ? "firstround" : "round")
    }

    new params[1]
    params[0] = 0
    set_task(10.0, "money_timeout", 5591, params, 0, "a", 1)
}

public rambo_slap(weapon_id) {
    if (!RAMBO)
        return

    // Find out player index
    new player = get_pdata_cbase(weapon_id, 41, 4) 
    user_slap(player, random_num(40, 60), 1)
}

public rambo_round_timeout() 
{
    server_cmd("amx_csay green !! RAMBOOO RUNDEEE !!")
    server_cmd("amx_csay red ALLE HEDDER JOHN!1!!")
    server_cmd("amx_csay blue RATATATATTATATATATATATATATATATATA")
    server_cmd("amx_csay red TATATATATATATATATATATATATATATATAT")
    server_exec()
}

public rambo_task(params[])
{
    new id = params[0]
    if (!is_user_alive(id))
        return

    give_item(id, "weapon_hegrenade")
    new weaponId = get_user_weapon(id)
    if (weaponId == CSW_M249) {
        client_cmd(id, "+attack") 
        cs_set_weapon_ammo(find_ent_by_owner(-1, "weapon_m249", id), 100);
    } else {
        client_cmd(id, "-attack;wait;-attack")
    }
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

public balance_players()
{
    //if (!ENABLED)
    //    return
    
    new arg[32]
    read_argv(1, arg, 32)

    if (equali(arg, ""))
        return

    new error
    new reqbuf[100]
    format(reqbuf, 100, "{\"cmd\":\"balance\",\"args\":{\"games\":%s}}", arg);
    balance_socket = socket_open(nobel_server_host, nobel_server_port, SOCKET_TCP, error)
    if (!error) {
        log_amx("Sending balance request: %s", reqbuf)
        socket_send(balance_socket, reqbuf, strlen(reqbuf))
        set_task(1.0, "receive_balanced_players", 1666, "", 0, "a", 5)
        set_task(3.0, "close_balance_socket", 1667, "", 0, "", 0)
    } else {
        log_amx("Error sending: %s", error)
        socket_close(balance_socket)
    }
}

public receive_balanced_players()
{
    new resbuf[1000]
    if (socket_is_readable(balance_socket)) {
        socket_recv(balance_socket, resbuf, 999)
        log_amx("Received data: %s", resbuf)

        new players[32], i, j, playerCount, resCount
        get_players(players, playerCount, "ch") 

        new JSON:response = json_parse(resbuf)
        resCount = json_array_get_count(response)
        log_amx("resCount: %d", resCount)

        /* For each player in response JSON */
        for (i = 0; i < resCount; i++) {
            new JSON:obj = json_array_get_value(response, i)
            new id[64] 
            new team[32] 

            json_object_get_string(obj, "steamid", id, 63)
            json_object_get_string(obj, "team", team, 31)
            log_amx("steamid: %s   newteam: %s", id, team)

            /* For each player in server */
            for (j = 0; j < playerCount; j++) {
                new playerName[64]
                new authid[64]
                new curTeam[64]

                get_user_authid(players[j], authid, charsmax(authid))
                get_user_name(players[j], playerName, charsmax(playerName))

                new CsTeams:curTeamId = cs_get_user_team(players[j])
                if (curTeamId == CS_TEAM_T)
                    curTeam = "T"
                else if (curTeamId == CS_TEAM_CT)
                    curTeam = "CT"

                if (equal(id, authid)) {
                    log_amx("Player %s, ID %s, curTeam: %s, newteam: %s", playerName, id, curTeam, team)

                    if (equali(team, "CT") && ! equali(curTeam, "CT")) {
                        log_amx("Moving %s (%d) from %s to %s", playerName, j, curTeam, team)
                        cs_set_user_team(players[j], CS_TEAM_CT)
                    } else if (equali(team, "T") && ! equali(curTeam, "T")) {
                        cs_set_user_team(players[j], CS_TEAM_T)
                        log_amx("Moving %s (%d) from %s to %s", playerName, j, curTeam, team)
                    }

                    break
                }
            }
        }

        // Flash? Lyd?
        // flash_all(10.0) 

        remove_task(1666)
    } else {
        log_amx("Socket was not readable")
    }
}

public flash_player(player, red, green, blue)
{
    message_begin(MSG_ONE, get_user_msgid("ScreenFade"), {0, 0, 0}, player);
    write_short(5<<12) // duration
    write_short(2<<6) // hold time
    write_short(0) // flags
    write_byte(red) // r
    write_byte(green) // g
    write_byte(blue) // b
    write_byte(250) // a
    message_end();
}

public close_balance_socket()
{
    socket_close(balance_socket)
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

public disable_bong_round()
{
    PAUSE = pause_enabled_before_kniferound
    BONG = false
    bong_next = false
    bong_last = false
    client_print(0, print_chat, "Nobel Bong Round disabled!")
    remove_task(1693)

    return PLUGIN_HANDLED;
}

public disable_rambo_round()
{
    PAUSE = pause_enabled_before_kniferound
    RAMBO = false
    rambo_next = false
    rambo_last = false
    client_print(0, print_chat, "Nobel RAMBO ROUND disabled!")
    remove_task(1692)

    return PLUGIN_HANDLED;
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

public cmd_nobel_balance(id, level, cid)
{
    if (!cmd_access(id, level, cid, 0))
        return PLUGIN_HANDLED;

    log_amx("nobel_balance called")
    balance_players()

    return PLUGIN_HANDLED;
}

public cmd_nobel_shuffle(id, level, cid)
{
    if (!cmd_access(id, level, cid, 0))
        return PLUGIN_HANDLED;

    if (ENABLED)
        shuffle_players()

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

public cmd_nobel_rambo(id, level, cid)
{
    if (!cmd_access(id, level, cid, 0))
        return PLUGIN_HANDLED;

    if (!ENABLED || KNIFE)
        return PLUGIN_HANDLED;

    if (!RAMBO && !rambo_next)
    {
        pause_enabled_before_kniferound = PAUSE

        server_cmd("amx_csay green NEXT ROUND IS RAMBO ROUND !!!!!")
        server_cmd("amx_csay red NEXT ROUND IS RAMBO ROUND !!!!!")
        server_cmd("amx_csay blue RATATATATATATATA !!!!")
        server_cmd("amx_csay red FAT DET !!!")
        server_exec()
        client_print(0, print_chat, "RAMBO ROUND enabled!")
        rambo_next = true
    }
    else
    {
        server_cmd("amx_csay green LAST RAMBO ROUND !!!!!")
        server_cmd("amx_csay red LAST RAMBO ROUND !!!!!")
        server_cmd("amx_csay blue LAST RAMBO ROUND !!!!!")
        server_cmd("amx_csay red FAT DET !!!")
        server_exec()
        rambo_last = true
    }

    return PLUGIN_HANDLED
}

public cmd_nobel_bong(id, level, cid)
{
    if (!cmd_access(id, level, cid, 0))
        return PLUGIN_HANDLED

    if (!ENABLED || KNIFE)
        return PLUGIN_HANDLED

    if (!BONG && !bong_next) {
        pause_enabled_before_kniferound = PAUSE

        server_cmd("amx_csay green PAS PÅ!!")
        server_cmd("amx_csay red DER ER BONG I LUFTEN")
        server_cmd("amx_csay blue drikdrikdrikdrikdrikdrikdrikdrik")
        server_exec()
        client_print(0, print_chat, "Nobel BONG ROUND enabled!")
        bong_next = true
    } else {
        bong_last = false
    }

    return PLUGIN_HANDLED
}

public cmd_nobel_knife(id, level, cid)
{
    if (!cmd_access(id, level, cid, 0))
        return PLUGIN_HANDLED;

    if (!ENABLED || RAMBO)
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
    if (!is_user_alive(id)) {
        return
    }

    client_cmd(id, "-attack") 

    if (FLASH)
    {
        give_item(id, "weapon_flashbang")
        give_item(id, "weapon_flashbang")
    }

    if (RAMBO) {
        strip_user_weapons(id)
        set_user_health(id, 200)
        give_item(id, "weapon_m249")
        give_item(id, "item_assaultsuit")
        give_item(id, "weapon_hegrenade")
        cs_set_user_bpammo(id, CSW_M249, 10000)

        log_amx("Adding rambo task for %d (%d)", id, id+100)
        new params[1]
        params[0] = id
        set_task(5.0, "rambo_task", id+100, params, 1, "b")
    }
}

// Triggered when TeamInfo changes
public player_switched_teams() 
{
    new id = read_data(1)
    new team[16]
    read_data(2, team, charsmax(team))

    new oldTeam[16]
    get_user_team(id, oldTeam, charsmax(oldTeam))

    new playerName[64]
    new steamID[32]
    get_user_name(id, playerName, charsmax(playerName))
    get_user_authid(id, steamID, charsmax(steamID))

    new JSON:obj = json_init_object()
    new JSON:args = json_init_object()
    json_object_set_string(obj, "cmd", "playerteam")

    json_object_set_string(args, "name", playerName)
    json_object_set_string(args, "id", steamID)
    json_object_set_string(args, "team", team)

    json_object_set_value(obj, "args", args)

    new buf[128]
    json_serial_to_string(obj, buf, charsmax(buf))

    json_free(args)
    json_free(obj)

    log_amx("CS event: %s switched to %s", playerName, team)
    send_json_always(buf)
}

// Triggered when client receives STEAMID
public client_authorized(id)
{
    new JSON:obj = json_init_object()
    json_object_set_string(obj, "cmd", "playerjoined")

    new JSON:args = json_init_object()
    new playerName[64]
    new steamID[32]
    new team[16]
    get_user_name(id, playerName, charsmax(playerName))
    get_user_authid(id, steamID, charsmax(steamID))
    get_user_team(id, team, charsmax(team))
    json_object_set_string(args, "id", steamID)
    json_object_set_string(args, "name", playerName)
    json_object_set_string(args, "team", team)

    json_object_set_value(obj, "args", args)

    new buf[256]
    json_serial_to_string(obj, buf, charsmax(buf))

    json_free(args)
    json_free(obj)

    log_amx("CS event: %s joined", playerName)
    send_json_always(buf)
}

public client_disconnected(id)
{
    new JSON:obj = json_init_object()
    json_object_set_string(obj, "cmd", "playerleft")

    new JSON:args = json_init_object()
    new playerName[64]
    new steamID[32]
    get_user_name(id, playerName, charsmax(playerName))
    get_user_authid(id, steamID, charsmax(steamID))
    json_object_set_string(args, "id", steamID)
    json_object_set_string(args, "name", playerName)

    json_object_set_value(obj, "args", args)

    new buf[256]
    json_serial_to_string(obj, buf, charsmax(buf))

    json_free(args)
    json_free(obj)

    log_amx("CS event: %s", buf)
    send_json_always(buf)
}

public cmd_nobel_sendplayers(id, level, cid)
{
    if (!cmd_access(id, level, cid, 0))
        return PLUGIN_HANDLED;

    send_players()

    return PLUGIN_HANDLED;
}

stock send_players()
{
    new Players[32]
    new playerCount, i
    new JSON:playersJson = json_init_object()
    new JSON:argsJson = json_init_array()
    json_object_set_string(playersJson, "cmd", "playersync")
    get_players(Players, playerCount, "c") 
    for (i=0; i<playerCount; i++)
    {
        new JSON:playerObject = json_init_object()
        new playerName[64]
        new steamID[32]
        new team[32]
        get_user_name(Players[i], playerName, charsmax(playerName))
        get_user_authid(Players[i], steamID, charsmax(steamID))
        get_user_team(Players[i], team, charsmax(team))
        json_object_set_string(playerObject, "id", steamID)
        json_object_set_string(playerObject, "name", playerName)
        json_object_set_string(playerObject, "team", team)
        json_array_append_value(argsJson, playerObject)
    }

    json_object_set_value(playersJson, "args", argsJson)

    // Can't figure out max buffer length. 2^12 is too big I think..?
    new buf[3072]
    json_serial_to_string(playersJson, buf, charsmax(buf))

    json_free(argsJson)
    json_free(playersJson)

    send_json_always(buf)
}

stock send_json(event[])
{
    if (ENABLED && SOUND) {
        send_json_always(event)
    }
}
stock send_json_always(event[]) {
    new sock
    new error
    sock = socket_open(nobel_server_host, nobel_server_port, SOCKET_TCP, error)
    if (!error) {
        log_amx("Sending JSON: %s", event)
        socket_send(sock, event, strlen(event))
        socket_close(sock)
    } else {
        log_amx("Error sending JSON: %s", error)
    }
}

stock send_event(cmd[], arg1[] = "", arg2[] = "")
{
    if (ENABLED) {
        send_event_always(cmd, arg1, arg2)
    }
}
stock send_event_always(cmd[], arg1[] = "", arg2[] = "")
{
    new JSON:eventJson = json_init_object()
    new JSON:argsJson = json_init_array()
    json_object_set_string(eventJson, "cmd", cmd)
    if (arg1[0]) {
        json_array_append_string(argsJson, arg1)
        if (arg2[0]) {
            json_array_append_string(argsJson, arg2)
        }
        json_object_set_value(eventJson, "args", argsJson)
    }

    new buf[512]
    json_serial_to_string(eventJson, buf, charsmax(buf))

    json_free(argsJson)
    json_free(eventJson)

    send_json_always(buf)
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
    send_players()

    // Load map type specific config
    new map_type_cfg[22]
    format(map_type_cfg, 22, "exec nobel_map_%s.cfg", map_type)
    log_amx("Executing: %s", map_type_cfg)
    server_cmd("nobel_balance 5")
    server_cmd(map_type_cfg)
    server_exec();
    round_time = (get_cvar_float("mp_roundtime") * 60.0)
    log_amx("Read mp_roundtime value=%f", round_time)

    server_cmd("exec server.cfg")
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
    PAUSE = true
    KNIFEPAUSE = true
    FLASHPROTECTION = false
    ANTIZOOMPISTOL = true

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

public cmd_nobel_knifepause(id, level, cid)
{
    if (!cmd_access(id, level, cid, 0))
        return PLUGIN_HANDLED;

    KNIFEPAUSE = !KNIFEPAUSE
    if (PAUSE)
        client_print(0, print_chat, "Nobel Beer CS knife pausing enabled")
    else
        client_print(0, print_chat, "Nobel Beer CS knife pausing disabled")
    return PLUGIN_HANDLED;
}

public cmd_nobel_antizoompistol(id, level, cid)
{
    if (!cmd_access(id, level, cid, 0))
        return PLUGIN_HANDLED;

    ANTIZOOMPISTOL = !ANTIZOOMPISTOL
    if (ANTIZOOMPISTOL)
        client_print(0, print_chat, "Nobel Beer CS antizoompistol enabled")
    else
        client_print(0, print_chat, "Nobel Beer CS antizoompistol disabled")
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

