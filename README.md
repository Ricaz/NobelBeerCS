# Hello Nobel!

This is a script for AMXMODX we wrote to make our drinking game more fun (and fair).

## Rules

We play a game at our LANs called Beer-CS (or Øl-CS in Danish), where, if you 
follow the rules, you get very drunk.
The rules for the game is as follows:

* There are 20 sips in one beer (33cl)
* When you drink, you must do so with your keyboard hand, so you can't move 
while drinking
* At the start of each round, everyone drinks 1 sip
* You drink 2 sips when you get a kill
* You drink 1 sip when you die
* You drink half a beer if you commit suicide
* You finish your beer if you kill a teammate
* When you get knifed, you must stand on your chair and say "I was knifed by <name>"

## Features

At first, we just wanted to make a mod that forced people to freeze when they got 
a kill, to prevent people from cheating (bind +forward on their mouse, for example).

Here is a list of current features:
* When you get a kill, you freeze for 5 seconds
* On the start of each map, the database and stats are reset. Stats are counted as sips.
  * Can be viewed by running `nobel_stats` by anyone in console
  * When anything happens in-game, the chat shows the amount of sips
  * Has experimental ping faker, so during the match, the amount of sips for 
  each player is shown in place of the latency
* All AMXMODX admins get a menu to unpause when a pause event occurs. Current pause events:
  * Knife kill
  * Team kill
  * Suicide

### Additional features

To add to the above (which is probably the best part of the mod), the 
mod can also connect to our media center, so it can play sounds and 
display images and videos on our big screen. Furthermore we have support
for several sound themes that can be changed by admins while playing the game.

* Plays a sound using `mpv` for various events, like:
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
* Available sound themes:
  * default (also a fallback theme if certain events does not exist in other themes)
  * jyde
  * bl (Blinkende Lygter)
  * olsenbanden
* Displays videos for:
  * Suicide
  * Team kill
  * Bomb exploded
* Displays images for knife kills using `feh`

## How it works

You have the AMXMODX addon (`nobel.sma`, needs compilation) running in your 
cstrike server. It opens a socket connection to the PHP server (in `/server`). 
This connection is used to send events about all kills and round starts.

The PHP server will handle events, eg. play a sound with `mpv` or generate 
images to be used on the web frontend (`stats.php`). It also forwards some of 
the events to the web application through a WebSocket connection.

## More info will come
