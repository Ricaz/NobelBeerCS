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
# All other configs (server.cfg, mr15.cfg, nobel_map_*.cfg, ...) go in cstrike/
for cfg in /nobel/*.cfg; do
    [ "$(basename "$cfg")" = nobel.cfg ] || cp "$cfg" $CSTRIKE/
done
# nobel_start/nobel_stop exec these; mr15.cfg must end with nobel_serverstart
[ -f $CSTRIKE/mr15.cfg ] || echo "nobel_serverstart" > $CSTRIKE/mr15.cfg
[ -f $CSTRIKE/stop.cfg ] || touch $CSTRIKE/stop.cfg

cd /home/steam/hlds
exec ./hlds_run -game cstrike -port 27015 +sv_lan 1 +maxplayers 16 +map "${MAP:-de_dust2}" "$@"
