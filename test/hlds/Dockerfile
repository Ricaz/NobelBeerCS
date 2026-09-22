# Local CS 1.6 dedicated server with Metamod-P and AMX Mod X, for testing nobel.sma.
FROM debian:bookworm-slim

RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends lib32gcc-s1 lib32stdc++6 libc6:i386 ca-certificates curl xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m steam
USER steam
WORKDIR /home/steam

# HLDS (app 90) is notoriously flaky to download, so retry a few times
RUN mkdir steamcmd && curl -sfL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz | tar xz -C steamcmd \
    && for i in 1 2 3 4 5; do \
        ./steamcmd/steamcmd.sh +force_install_dir /home/steam/hlds +login anonymous \
            +app_set_config 90 mod cstrike +app_update 90 validate +quit \
        && [ -f hlds/cstrike/liblist.gam ] && break; \
    done \
    && test -f hlds/cstrike/liblist.gam \
    && rm -rf /home/steam/Steam/logs /home/steam/Steam/appcache \
    && mkdir -p .steam/sdk32 && ln -s /home/steam/steamcmd/linux32/steamclient.so .steam/sdk32/steamclient.so

ARG METAMOD_URL=https://github.com/Bots-United/metamod-p/releases/download/v1.21p109/metamod-p-v1.21p109-linux_ubuntu1804.tar.xz
ARG AMXX_URL=https://www.amxmodx.org/amxxdrop/1.10/amxmodx-1.10.0-git5486
# HLDS has no built-in bots for CS 1.6, so use YaPB
ARG YAPB_URL=https://github.com/yapb/yapb/releases/download/4.4.957/yapb-4.4.957-linux.tar.xz
WORKDIR /home/steam/hlds/cstrike
RUN curl -sfL "$METAMOD_URL" | tar xJ \
    && curl -sfL "$AMXX_URL-base-linux.tar.gz" | tar xz \
    && curl -sfL "$AMXX_URL-cstrike-linux.tar.gz" | tar xz \
    && curl -sfL "$YAPB_URL" | tar xJ \
    && printf 'linux addons/amxmodx/dlls/amxmodx_mm_i386.so\nlinux addons/yapb/bin/yapb.so\n' > addons/metamod/plugins.ini \
    && sed -i 's#^gamedll_linux .*#gamedll_linux "addons/metamod/dlls/metamod.so"#' liblist.gam \
    && echo '"127.0.0.1" "" "abcdefghijklmnopqrstu" "de"' >> addons/amxmodx/configs/users.ini

WORKDIR /home/steam/hlds
COPY --chown=steam entrypoint.sh /home/steam/entrypoint.sh
ENTRYPOINT ["/home/steam/entrypoint.sh"]
