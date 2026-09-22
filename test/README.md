# Testing locally

## Web app only (no CS server)

`server/src/tools/fake-mod.mjs` sends a short game's worth of events over UDP,
exactly like the plugin does:

```sh
cd server
npm run build && npm run start          # in one terminal
node src/tools/fake-mod.mjs             # in another: [host] [port] [delay-ms]
```

Open https://localhost:27016 to watch the scoreboard and hear the sounds.

## Full setup with a local CS 1.6 server

`test/hlds` contains a Docker image with HLDS, Metamod-P, AMX Mod X 1.10 and
YaPB bots. On startup it compiles `cstrike/nobel.sma` from this repo and installs
the configs, so restarting the container picks up your changes.

```sh
# 1. Start the web app (see above) so the plugin has something to talk to
# 2. Build and start the server (first build downloads ~600 MB)
cd test/hlds
docker compose up --build

# 3. Control it with rcon from the repo root
node test/rcon.mjs nobel_bots 1       # count bots as players
node test/rcon.mjs yb_quota 6         # add 6 bots
node test/rcon.mjs nobel_start
node test/rcon.mjs nobel_serverstart
node test/rcon.mjs nobel               # show settings
```

Plugin logs show up in the container output (`[nobel.amxx] ...`).

The container uses host networking, so it reaches the web app on `127.0.0.1:1337`,
and you can join from your own CS client with `connect 127.0.0.1` to test things
bots can't (freezing, the pause menu). Connections from 127.0.0.1 get admin rights.

Things to know:

- Bots get fake IDs like `BOT_<name>`, since they all share the Steam ID `BOT`.
  Without `nobel_bots 1`, bots are ignored just like in a real game.
- Pausing (`amx_pause`) needs a real player on the server.
- `sv_restart` resets the map timer, so the half-time team switch happens
  `mp_timelimit / 2` minutes after the last restart. Set `mp_timelimit 1` to test it quickly.
