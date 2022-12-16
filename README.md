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

The rules for the game is as follows:

* There are 20 sips in one beer (33cl)
* When you drink, you must do so with your keyboard hand, so you can't move 
while drinking
* At the start of each round, everyone drinks 1 sip (*FÆLLES KÅÅÅL*)
* You drink 2 sips when you get a kill
* You drink 1 sip when you die
* You drink half a beer if you commit suicide
* You finish your beer if you kill a teammate
* When you get knifed, you must stand on your chair and say "I was knifed by <name>"

## Main mod features

At first, we just wanted to make a mod that forced people to freeze when they got 
a kill, to prevent people from cheating (bind +forward on their mouse, for example).

Here is a list of current features:
* When you get a kill, you freeze for 4-5 seconds
* When you kill your teammates, commit suicide, or get a knife kill, the game pauses
  * This is to allow you to announce your shame or finish your beer while everyone waits
  * Admins will get a pop-up menu allowing them to unpause when ready

Of course, everyone is encouraged to say *SKÅL* to thier victims/killers!

### Additional features

To add to the above (which is probably the best part of the mod), we also have 
lots of additional features to add to the chaos.

* Half-way team switch
  * Everyone will swap teams mid-game (without warning) half-way through the match
* Antizoompistol (`nobel_antizoompistol`, defaults to `1`)
  * Punishes people using AWP or autosnipers by slapping them for a random amount
* Technoflash (`nobel_flashprotection`, defaults to `1`)
  * Nerfs flashbangs at the start of the round, to prevent griefing new players
    who don't know the way out of spawn while blind 
* LEJFRUNDE (`nobel_knife`, toggleable)
  * In the next round, only knife and grenade *kills* are allowed
  * Killing people with guns counts as a teamkill
* Rambo-mode (`nobel_rambo`, experimental)
  * In the next round, everyone gets an M249 with infinite ammo and a continuous supply of HE grenades
  * You cannot stop firing the gun
  * Kinda glitchy, especially if people try to circumvent the safeguards against using other weapons 
* Autobalance (`nobel_balance`, experimental)
  * Uses scores calculated (K/D) by the webserver to balance the teams
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
resulting binary in `addons/amxmodx/plugins/`.

You can start the mod using `nobel_start`.

### Web application
The separate web server is optional, but highly recommended. You will need to configure 
`nobel_server_host` and `nobel_server_port` inside `amxmodx/nobel.cfg` for it to connect.

It opens a socket connection to our NodeJS server (in `/server`). 
This connection is used to send events about all kills and round starts.
