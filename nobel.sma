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

#define PLUGIN "Nobel Beer CS"
#define AUTHOR "Nobel Kollegiet"
#define VERSION "1.7"
#define ACCESS ADMIN_SLAY
#define MOD_STATE_STOPPED "STOPPED"
#define MOD_STATE_STARTING "STARTING"
#define MOD_STATE_STARTED "STARTED"

new bool:ENABLED = false
new bool:PAUSE = false
new bool:SOUND = false
new bool:FLASH = false
new bool:BADUM = false
new bool:KNIFE = false

new pauseMenu

new nobel_server_host[50]
new nobel_server_port
new Handle:db
new db_available = true
new mod_state[10] = MOD_STATE_STOPPED
new bool:knife_next = false
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

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR)
    register_event("HLTV", "round_start", "a", "1=0", "2=0")
    register_event("HLTV", "event_new_round", "a", "1=0", "2=0")
    register_event("DeathMsg", "hook_death", "a")
    register_event("TeamInfo", "fix_sip_count", "a")
    register_event("CurWeapon", "set_user_speed", "be") 
    register_logevent("team_win", 2, "1=Round_End");
    register_logevent("event_round_start", 2, "1=Round_Start")
    register_logevent("bomb_planted_custom", 3, "2=Planted_The_Bomb")
    register_logevent("bomb_explode_custom", 6, "3=Target_Bombed")
    register_logevent("bomb_defused", 3, "2=Defused_The_Bomb")
    register_message(get_user_msgid("TextMsg"), "message_textmsg")
    register_forward(FM_UpdateClientData, "fw_UpdateClientData")
    RegisterHam(Ham_Spawn, "player", "player_spawned", 1);
    RegisterHam(Ham_Weapon_WeaponIdle, "weapon_flashbang", "weapon_idle_flashbang")

    register_concmd("nobel_pause", "cmd_nobel_pause", ACCESS, "Pause the plugin.")
    register_concmd("nobel_sound", "cmd_nobel_sound", ACCESS, "Enable/disable sound.")
    register_concmd("nobel_badum", "cmd_nobel_badum", ACCESS, "Enable/disable badum.")
    register_concmd("nobel_theme", "cmd_nobel_theme", ACCESS, "Change sound theme.")
    register_concmd("badum", "cmd_badum", ACCESS, "Plays badum!")
    register_concmd("nobel", "cmd_nobel", ACCESS, "View current settings.")
    register_concmd("nobelstats", "cmd_nobel_stats", ACCESS, "View simple stats.")
    register_concmd("nobel_stats", "cmd_nobel_stats", ACCESS, "View simple stats.")
    register_concmd("nobel_full_stats", "cmd_nobel_full_stats", ACCESS, "View full stats.")
    register_concmd("nobel_clear_stats", "cmd_nobel_clear_stats", ACCESS, "Clear all stats.")
    register_concmd("nobel_start", "cmd_nobel_start", ACCESS, "Start the plugin.")
    register_concmd("nobel_serverstart", "cmd_nobel_serverstart", ACCESS, "")
    register_concmd("nobel_stop", "cmd_nobel_stop", ACCESS, "Stop the plugin.")
    register_concmd("nobel_flash", "cmd_nobel_flash", ACCESS, "Toggle the flash functionality.")
    register_concmd("nobel_knife", "cmd_nobel_knife", ACCESS, "Toggle the knife functionality.")
    register_concmd("nobel_shuffle", "cmd_nobel_shuffle", ACCESS, "Shuffle the teeeams.")

//    register_concmd("nobel_fake_pausemenu", "cmd_nobel_fake_pausemenu", ACCESS, "Fakes the pause menu.")
    create_menus()

    // Read configuration values from config/nobel.cfg
    register_cvar("nobel_server_host", "localhost")
    register_cvar("nobel_server_port", "1337")
    register_cvar("nobel_db_host", "localhost")
    register_cvar("nobel_db_user", "root")
    register_cvar("nobel_db_pass", "root")
    register_cvar("nobel_db_database", "beer_cs")

    map_time_half = ((get_cvar_num("mp_timelimit") * 60) / 2)
    round_time = (get_cvar_float("mp_roundtime") * 60.0)

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

    nobelix_cmd_always("stats")

    new db_error[512]
    new ErrorCode,Handle:SqlConnection = SQL_Connect(db,ErrorCode,db_error,511)
    if(SqlConnection == Empty_Handle) {
        db_available=false
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

public weapon_idle_flashbang(id)
{
    if (FLASH && !flash_thrown)
    {
        flash_thrown = true
        client_cmd(0, "+attack")
        client_cmd(0, "wait")
        client_cmd(0, "-attack")
    }
}

public event_new_round() {
    remove_task(7748)
    freezetime = true
}

public event_round_start() {

    if (!ENABLED)
        return

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
    set_task(8.0, "shieldforce_timeout", 3233, params, 0, "a", 1)
    set_task((round_time - 19.0), "roundending", 6681, params, 0, "a", 1)
}

public shieldforce_timeout() {
    if (!ENABLED)
        return

    new players[32]
    new playerCount, i
    get_players(players, playerCount, "c")
    new shield_t = 0, shield_ct = 0
    new CsTeams:team
    for (i=0; i<playerCount; i++)
    {
        team = cs_get_user_team(players[i])
        if (team == CS_TEAM_T) 
        {
            shield_t += cs_get_user_shield(players[i])
        }
        else if (team == CS_TEAM_CT)
        {
            shield_ct += cs_get_user_shield(players[i])
        }
    }

    if (shield_t >= 2 || shield_ct >= 2)
    {
        nobelix_cmd("shieldforce")
    }
}

public roundending() {
    if (!ENABLED)
        return

    if (!defused) {
        nobelix_cmd("roundending")
    }
}

public team_win(plaf) {
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
        nobelix_cmd("winstreak")
    }
}

public bomb_defused() {
    if (!ENABLED)
        return
    remove_task(7748)
    defused = true
    nobelix_cmd("bombdefused")
}

public bomb_planted_custom() {
    if (!ENABLED)
        return
    new params[1]
    params[0] = 0
    remove_task(6681)
    set_task(25.0, "bomb_planted_timeout", 7748, params, 0, "a", 1)
    nobelix_cmd("bombplanted")
}

public bomb_planted_timeout() {
    if (!ENABLED)
        return
    if (!defused) {
        nobelix_cmd("hurryup")
    }
}

public bomb_explode_custom(planter, defuser) {
    if (!ENABLED)
        return
    exploded = true
    remove_task(7748)
    nobelix_cmd("bombexploded")
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
        teams_switched = true

        log_amx("Flipping teams")
        nobelix_cmd("teamswitch")        

        new players[32] 
        new playerCount, i 
        get_players(players, playerCount, "c") 

        for (i = 0; i < playerCount; i++) {
            new playerName[64]
            get_user_name(players[i], playerName, charsmax(playerName))
            new CsTeams:teamid = cs_get_user_team(players[i])
            if (teamid == CS_TEAM_T)
            {
                log_amx("Putting %s on team CT", playerName)
                cs_set_user_team(players[i], CS_TEAM_CT)
            } 
            else if (teamid == CS_TEAM_CT) 
            {
                log_amx("Putting %s on team T", playerName)
                cs_set_user_team(players[i], CS_TEAM_T)
            }
        }
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
    menu_additem(pauseMenu, "Unpause", "1", 0)
    menu_setprop(pauseMenu, MPROP_PERPAGE, 0)
}

public pause_menu_handler(id, menu, item)
{
    if (item == 9)
    {
        new Players[32] 
        new playerCount, i 
        get_players(Players, playerCount, "c") 
        for (i=0; i<playerCount; i++)
        {
            if (is_user_admin(Players[i]))
            {
                show_menu(Players[i], 0, " ", 0)
            }
        }

        nobelix_cmd("unpause")

        client_print(0, print_chat, "Go go go!")
        unpause_game()
    }
    return PLUGIN_HANDLED;
}

public pause_game()
{
    if (!is_paused)
    {
        is_paused = true
        server_cmd("amx_pause")
        server_exec()
    }
}

public unpause_game()
{
    if (is_paused)
    {
        is_paused = false
        server_cmd("amx_pause")
        server_exec()
    }
}

public hook_death()
{
    fix_sip_count()

    if (!ENABLED)
        return

    new killer = read_data(1)
    new victim = read_data(2)
    new headshot = read_data(3)
    new killername[64]
    new victimname[64]
    new killersteamid[64]
    new victimsteamid[64]
    new weapon[32]
    read_data(4, weapon, 31)
    new knifed = !strcmp(weapon, "knife")
    new grenade = !strcmp(weapon, "grenade")

    if (killer == 0 || victim == 0)
        return

    new CsTeams:killerteam = cs_get_user_team(killer)
    new CsTeams:victimteam = cs_get_user_team(victim)

    new team_kill = killer != victim && killerteam == victimteam
    new suicide = killer == victim
    get_user_name(killer, killername, 63)
    get_user_name(victim, victimname, 63)
    get_user_authid(killer, killersteamid, charsmax(killersteamid))
    get_user_authid(victim, victimsteamid, charsmax(victimsteamid))

    client_print(0, print_chat, "%s drinks 2!", killername)
    client_print(0, print_chat, "%s drinks 1!", victimname)
   
    // Find out if the user is the worst on the team
    new players[32]
    new playerCount, i, worstplayer = false
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

    // UPDATE STATS
    if (team_kill)
    {
        db_update(killer, killersteamid, killername, 0, 1, 0, 0, 5)
        db_update(victim, victimsteamid, victimname, 1, 0, 0, 0, 1)
    }
    else if (suicide)
    {
        db_update(killer, killersteamid, killername, 0, 0, 0, 0, 1)
    }
    else
    {
        db_update(killer, killersteamid, killername, 1, 0, 0, 0, 2)
        db_update(victim, victimsteamid, victimname, 0, 0, 0, 0, 1)
    }

    if (knifed)
    {
        db_update(killer, killersteamid, killername, 0, 0, 1, 0, 0)
        db_update(victim, victimsteamid, victimname, 0, 0, 0, 1, 0)
    }

    // EVENT CONTROL
    if (team_kill)
    {
        nobelix_cmd("tk", killername, victimname)
        client_print(0, print_chat, "Bottoms up, %s!", killername)
        pause_or_freeze_player(killer)
    }
    else if (KNIFE && !knifed && !grenade)
    {
        // In knife rounds we do NOT accept to be killed by a gun!
        nobelix_cmd("kniferound", killername)
        client_print(0, print_chat, "Bottoms up, %s!", killername)
        pause_or_freeze_player(killer)
    }
    else if (knifed && !KNIFE)
    {
        nobelix_cmd("knife", killername, victimname)
        client_print(0, print_chat, "%s got KNIFED!", victimname)
        pause_or_freeze_player(killer)
    }
    else if (grenade)
    {
        nobelix_cmd("grenade")
    }
    else if (headshot)
    {
        nobelix_cmd(worstplayer ? "worstplayer" : "headshot")
        freeze_player(killer)
    }
    else if (suicide)
    {
        nobelix_cmd(worstplayer ? "worstplayer" : "kill")
        // Do not freeze user, as the last user could get unfreezed
        // in a new round while round start freezetime is activated
    }
    else
    {
        nobelix_cmd(worstplayer ? "worstplayer" : "kill")
        freeze_player(killer)
    }
}

public pause_or_freeze_player(killer)
{
    if (PAUSE)
    {
        pause_game()
        new players[32] 
        new playerCount, i 
        get_players(players, playerCount, "c") 
        for (i=0; i<playerCount; i++)
        {
            if (is_user_admin(players[i]))
            {
                menu_display(players[i], pauseMenu, 0)
            }
        }
    }
    else
    {
        freeze_player(killer)
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

    if (KNIFE)
    {
        new params[1]
        params[0] = 0
        set_task(1.0, "knife_round_timeout", 1691, params, 0, "a", 1)
    }

    round_count++
    client_print(0, print_chat, "Cheers! Everyone drinks 1!")

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
        }
    }

    if (KNIFE) {
        nobelix_cmd("leif")
    } else {
        nobelix_cmd("round")
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
        if ((player_money[i] - current_money) > 5700) {
            any = true
        }
    }

    if (any)
        nobelix_cmd("rich")
}

public cmd_nobel_shuffle()
{
    new players[32] 
    new playerCount 
    get_players(players, playerCount, "c") 
    
    SortCustom1D(players, playerCount, "do_the_shuffle")

    log_amx("---- SORT RESULT ----")
    for (new i=0; i < playerCount; i++)
    {
        new playerName[64]
        get_user_name(players[i], playerName, charsmax(playerName))
        log_amx("Player: %s", playerName)
    }
    return PLUGIN_HANDLED
}

public do_the_shuffle(elm1, elm2)
{
    return random_num(-1, 1)
}


//new Array:playerList = ArrayCreate(10)
//
//public shuffle_players(i, players, min, max) {
//	if (min == max)
//		return
//	new rand = random_num(min, max)
//	log_amx("Shuffling.. rand=%d, min=%d, max=%d", rand, min, max)
//    ArrayPushInt(playerList, players[rand])
//	if (min < rand)
//		shuffle_players(++i, players, min, rand)
//	else
//		shuffle_players(++i, players, rand, max)
//}
//
//
//public cmd_nobel_shuffle()
//{
//	new num, players[32]
//	get_players(players,num)
//
//	shuffle_player(0, players, 0, num)
//    log_amx("--- RESULT ---")
//    for (new i=0, i < num; i++)
//    {
//        new player[64]
//        new playerId = ArrayGetCell(playerList, i)
//        get_user_name(playerId, player, 63)
//        log_amx("Player: %s", player)
//    }
//
//    return PLUGIN_HANDLED
//
////    new Players[32] 
////    new playerCount
////    get_players(Players, playerCount, "c") 
////    new Array:shuffledPlayers = ArrayCreate(playerCount)
////    for (new i = 0; i < playerCount; i++)
////    {
////        ArrayPushCell(shuffledPlayers, Players[random_num(i++, playerCount - 1)]);
////    }
////
////    log_amx("-----------------")
////
////    for (new j = 0; j < playerCount; j++)
////    {
////        new playerName[50]
////        get_user_name( ArrayGetCell(shuffledPlayers, j), playerName, charsmax(playerName) );
////        log_amx("Player: %s", playerName);
////    }
//}

public cmd_nobel_knife(id, level, cid)
{
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
        PAUSE = pause_enabled_before_kniferound
        KNIFE = false
        knife_next = false
        client_print(0, print_chat, "Nobel LAAAJF ROUND disabled!")
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
        client_print(0, print_chat, "Nobel TIIIIIM FLASH %s!", (FLASH ? "enabled" : "disabled"))
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
        nobelix_cmd("theme", arg)
    }
    return PLUGIN_HANDLED
}

public cmd_badum(id, level, cid)
{
    if (!cmd_access(id, level, cid, 0))
        return PLUGIN_HANDLED;

    if (BADUM)
        nobelix_cmd("badum")    
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

stock nobelix_cmd(cmd[], name[] = "", name2[] = "")
{
    if (ENABLED && SOUND) {
        nobelix_cmd_always(cmd, name, name2)
    }
}

stock nobelix_cmd_always(cmd[], name[] = "", name2[] = "")
{
    new sock
    new error
    sock = socket_open(nobel_server_host, nobel_server_port, SOCKET_TCP, error)
    if (!error)
    {
        new buf[64]
        format(buf, 64, "%s|€@!|%s|€@!|%s", cmd, name, name2)
        new len = strlen(buf)
    
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
    return PLUGIN_HANDLED;
}

public cmd_nobel_start(id, level, cid)
{
    if (!cmd_access(id, level, cid, 0) || !in_state(MOD_STATE_STOPPED))
        return PLUGIN_HANDLED;

    round_count = 0
    set_state(MOD_STATE_STARTING)

    server_cmd("exec mr15.cfg")

    new params[1]
    params[0] = 0

    set_task(1.0, "periodic_timer", 1000, params, 0, "a", 2147483647)
    return PLUGIN_HANDLED;
}

public cmd_nobel_serverstart(id, level, cid)
{
    if (!cmd_access(id, level, cid, 0))
        return PLUGIN_HANDLED;

    ENABLED = true
    SOUND = true
    
    if (db_available) {
        cmd_nobel_clear_stats(0, 0, 0)
        PAUSE = true
    }
    
    round_start()
    set_state(MOD_STATE_STARTED)

    return PLUGIN_HANDLED;
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

    nobelix_cmd("clearstats")    

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

