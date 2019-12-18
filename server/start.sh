#!/bin/bash

function diediedie {
	echo "Shutting down.."
	# Force-kill all backgrounded processes
	kill -9 $CURSOR_PID &> /dev/null
	kill -9 $CHROMIUM_PID &> /dev/null
	kill -9 $PHP_PID &> /dev/null
	kill -9 $APLAY_PID &> /dev/null
}

echo "Starting stats system"
export DISPLAY=:0

trap "diediedie" EXIT

# Pulseaudio kører som systemservice, så det burde ikke længere være nødvendigt at starte den for brugeren her
# pulseaudio --start

# Fix HDMI sound problem
aplay -c2 -r48000 -fS16_LE < /dev/zero &
APLAY_PID=$!

# Start the built-in PHP webserver in background
php -S 0.0.0.0:1234 -t /home/oelcs &
PHP_PID=$!

#Start 
xset -dpms
xset s off
openbox-session &

# Start chromium and load stats page
chromium --disable-infobars --autoplay-policy=no-user-gesture-required --disable-session-crashed-bubble --kiosk --app=http://localhost:1234/stats.php &
#chromium --disable-session-crashed-bubble --app=http://localhost:1234/stats.php &
CHROMIUM_PID=$!

# Hide the mouse cursor
unclutter -root -idle 0 &
CURSOR_PID=$!

echo "APLAY_PID: $APLAY_PID"
echo "PHP_PID: $PHP_PID"
echo "CHROMIUM_PID: $CHROMIUM_PID"
echo "CURSOR_PID: $CURSOR_PID"

# Start the real deal!
cd /home/oelcs/
php nobel_beer_cs.php
