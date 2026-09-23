# Øl-CS

A LAN-friendly drinking game mod for Counter-Strike 1.6.

## Background

During our frequent LAN parties, we usually end the evenings in a CS
beer-drinking extravaganza.

It became tough to enforce the rules, and thus spawned an AMXMODX mod to
automate most of them. The idea is that if you get a lot of kills, you
get increasingly drunk, *theoretically* balancing the game.

The project also includes a seperate web app, which receives all events
from the CS server, keeping track of the scoreboard (to display on a large
screen), as well as play a myriad of sounds for each situation. We usually
use Chromecast for this.  Check out the separate [README in server/](server/) (WIP).

## Rules

General rules:
* When you get a kill, start drinking immediately
* You must always drink with your keyboard hand
* When you get knifed, stand on your chair and say "I was knifed by NAME" (probably Emil)
* **RIGTIGE NAVNE**: Your in-game name *must end* with your real name (for skål purposes)

Drinking rules:
* There are 20 sips in a 33cl beer
* At the start of each round, everyone drinks 1 sip (*FÆLLES KÅÅÅL*)
* Get a kill: 2 sips
* Get killed: 1 sip
* Suicide: 10 sips
* Teamkill: Finish your beer!

## Main mod features

At first, we just wanted to make a mod that forced people to freeze when they got 
a kill, to prevent people from cheating (bind `+forward` on their mouse, for example).

Here is a list of current features:
* When you get a kill, you freeze for 4-5 seconds
* When you kill your teammates, commit suicide, or get a knife kill, the game pauses
  * This is to allow you to announce your shame or finish your beer while everyone waits
  * Admins will get a pop-up menu allowing them to unpause when ready

Of course, everyone is encouraged to say *SKÅL* to thier victims/killers!

### Additional features

To add to the above (which is probably the best part of the mod), we also have 
lots of additional features to add to the chaos.

All the commands are toggleable.

* Half-way team switch
  * Everyone will swap teams mid-game (without warning) half-way through the match
* Antizoompistol (`nobel_antizoompistol`)
  * Punishes people using AWP or autosnipers by slapping them for a random amount
* Technoflash (`nobel_flashprotection`)
  * Nerfs flashbangs at the start of the round, to prevent griefing new players
    who don't know the way out of spawn while blind 
* LEJFRUNDE (`nobel_knife`)
  * In the next round, only knife and grenade *kills* are allowed
  * Killing people with guns counts as a teamkill
* Rambo-mode (`nobel_rambo`)
  * In the next round, everyone gets an M249 with infinite ammo and a continuous supply of HE grenades
  * You cannot stop firing the gun
  * No bomb and no buying, and a song plays on repeat throughout the round
  * Kinda glitchy, especially if people try to circumvent the safeguards against using other weapons 
* Mario Kart round (`nobel_kart`)
  * A knife-only race to the other team's spawn, with a 3 minute round: each player who gets
    there scores a point and goes back to their own spawn. The first team to 10 points wins.
    When time runs out, the team with the most points wins; on a tie it's sudden death, with
    another minute on the clock (as often as needed) and the next point winning.
  * The losers drink half a beer: after the win sound they're slain, and the game pauses with
    a song and their names on the big screen. In the admin pause menu, 9 ends Mario Kart and
    0 races again.
  * Everyone gets only a knife, and nothing can be bought or picked up
  * Nobody can die: only an enemy's knife (and fireballs) hurts, and the hit that would kill
    sends you back to your own spawn with full health. The victim is frozen to drink 2 sips,
    and the killer gets a frag in-game and $350.
  * Item boxes around the map: run over one to get an item, fire it with `+use` (E) or the
    flashlight key (F). Mushroom, banana, green shell, star, lightning, blue shell, bob-omb
    and fire flower (5 fireballs). Items hit teammates too, and your own green shell can hit
    you, but the blue shell only goes for enemies. Green shells are the most common, lightning
    and blue shells are rare, and the team behind on points gets slightly better items.
    Getting hit costs a sip. Hits pay the shooter: $300 for a green shell, $100 per player
    blown up by a bob-omb and $50 for a fireball.
  * Item boxes go where players have stood during normal rounds (saved per map in
    `data/nobel_spots/`), so a new map needs a round or two first
  * Sounds go in the web app's `mariokart` and `mk_*` media folders, which are kept out of git
* Sips in the scoreboard (`nobel_sips`, on by default)
  * The in-game scoreboard's Money column shows each player's sips (needs the web app and the
    updated CS 1.6 client with HP and Money columns)
* Noob buff (`nobel_noobbuff`, on by default)
  * Compensates badly performing players
* Teleswap (`nobel_teleswap`, off by default)
  * Each round has a 20% chance that a random T and CT swap places (at least 30 seconds in),
    with a short flash and a sound
  * `nobel_teleswapnow [player] [player]` swaps two players right away (a random T and CT without names)
* Autobalance (`nobel_balance <games>`, runs automatically with `nobel_start`)
  * Rates each player by kills/deaths over their own last `<games>` games (50 by default)
  * Picks a random split among the ones where the teams' average ratings are within 3%,
    so teams vary between maps, and randomizes which team plays CT
  * Happens immediately when run, ie. people will switch teams in a live game (and survive)
* Plays a sound in the browser for various events, like:
  * Round start
  * Knife kills
  * Regular kills
  * Headshots
  * Suicide
  * Gets a kill by grenade
  * When a player is the only one left on the team
  * Big spender
  * 18 seconds remaining in a round
  * Bomb planted
  * Bomb defused
  * Knife round starts
  * First hostage follow
  * All hostages rescued
  * When more than 2 players has a shield after buy
  * Worst player gets a kill
  * When a team is on a winning streak
  * Unpause
  * ... An a few more
* Multiple sound themes (changable with `nobel_theme`)
  * default (also a fallback theme if certain events does not exist in other themes)
  * jyde
  * bl (Blinkende Lygter)
  * olsenbanden
* Displays videos for:
  * Suicide
  * Team kill
  * Bomb exploded

The sounds are highly recommended as they make the experience much more fun.

## Usage

Requires `amxmodx` versions `1.10` or above.

You compile `nobel.sma` with the `amxxpc` compiler included with AMXModX and put the
resulting binary in `addons/amxmodx/plugins/`. Copy `nobel.cfg` and `nobel_players.ini`
to `addons/amxmodx/configs/`.

You can start the mod using `nobel_start`.

Settings like `nobel_pause` toggle when run without an argument, or can be set
explicitly with `nobel_pause 0`/`nobel_pause 1`. Run `nobel` to see all settings.

### Personal sounds

`nobel_players.ini` maps Steam IDs to personal sounds and chat messages for
teamkills and knife kills. The sound is the name of a folder in the web app's
media directory.

### Web application
The separate web server is optional, but highly recommended. You will need to configure 
`nobel_server_host` and `nobel_server_port` inside `amxmodx/nobel.cfg` for it to connect.

The mod sends events about all kills and round starts to our NodeJS server (in `/server`)
as JSON over UDP, so a slow or unavailable web server never lags the game. Make sure
the UDP port is open if the web server runs on another machine.

## Testing

See [test/README.md](test/) for running the web app and a local CS server with bots in Docker.
