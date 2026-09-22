#!/bin/sh
# Compiles and installs the mounted plugin (/nobel = repo's cstrike/ dir), then starts HLDS.
set -e
CSTRIKE=/home/steam/hlds/cstrike
AMXX=$CSTRIKE/addons/amxmodx

cd $AMXX/scripting
./amxxpc /nobel/nobel.sma -o$AMXX/plugins/nobel.amxx
grep -q '^nobel.amxx' $AMXX/configs/plugins.ini || echo "nobel.amxx" >> $AMXX/configs/plugins.ini

cp /nobel/nobel_players.ini $AMXX/configs/
sed "s/^nobel_server_host.*/nobel_server_host \"${NOBEL_SERVER_HOST:-127.0.0.1}\"/" /nobel/nobel.cfg > $AMXX/configs/nobel.cfg
cp /nobel/nobel_map_*.cfg $CSTRIKE/
cp /nobel/server.cfg $CSTRIKE/server.cfg
touch $CSTRIKE/mr15.cfg $CSTRIKE/stop.cfg

cd /home/steam/hlds
exec ./hlds_run -game cstrike -port 27015 +sv_lan 1 +maxplayers 16 +map "${MAP:-de_dust2}" "$@"
