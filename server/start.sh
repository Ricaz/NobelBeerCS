#!/bin/bash

function diediedie {
	# Force-kill all backgrounded processes
	kill -9 $CURSOR_PID
	kill -9 $CHROMIUM_PID
	kill -9 $PHP_PID
	kill -9 $APLAY_PID
}

echo "Starting stats system"
export DISPLAY=:0

trap "diediedie" SIGHUP SIGINT SIGTERM

# Fix HDMI sound problem
aplay -c2 -r48000 -fS16_LE < /dev/zero &
APLAY_PID=$!

# Start the built-in PHP webserver in background
php -S 0.0.0.0:1234 &
PHP_PID=$!

# Start chromium and load stats page
chromium --disable-infobars --disable-session-crashed-bubble -kiosk http://localhost:1234/stats.php &
CHROMIUM_PID=$!

# Hide the mouse cursor
unclutter -root -idle 0 &
CURSOR_PID=$!

echo "APLAY_PID: $APLAY_PID"
echo "PHP_PID: $PHP_PID"
echo "CHROMIUM_PID: $CHROMIUM_PID"
echo "CURSOR_PID: $CURSOR_PID"

# Start the real deal!
php nobel_beer_cs.php

