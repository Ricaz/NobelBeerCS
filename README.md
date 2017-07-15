# Hello World!

This is a script for AMXMODX we wrote to make our drinking game more fun (and fair).

## Rules

We play a game at our LANs called Beer-CS (or Øl-CS in Danish), where, if you follow the rules, you get very drunk.
The rules for the game is as follows:

* There are 10-15 sips in one beer (33cl)
* At the start of each round, everyone drinks 1 sip
* When you drink, you must do so with your keyboard hand, so you can't move while drinking
* You drink 2 sips when you get a kill
* You drink 1 sip when you die
* You finish your beer if you kill a teammate
* When you get knifed, you must stand on your chair and say "I was knifed by <name>"

## Features

At first, we just wanted to make a mod that forced people to freeze when they got a kill, to prevent people from cheating (bind +forward on their mouse, for example).

Here is a list of current features:
* When you get a kill, you freeze for ~4 seconds
* On the start of each map, the database and stats are reset. Stats are counted as sips.
..* Can be viewed by running `nobel_stats` by anyone in console
..* When anything happens in-game, the chat shows the amount of sips
..* Has experimental ping faker, so during the match, the amount of sips for each player is shown in place of the latency
* On a knife kill, the game pauses.
..* All AMXMODX admins get a menu to unpause when this occurs

### Additional features

To add to the above (which is probably the best part of the mod), the mod can also connect to our mediacenter, so it can play sounds and display images on our big screen.

* Plays a sound on round start, knife kills, and headshots
* Displays images for knife kills and headshots using `feh`

# More info will come
