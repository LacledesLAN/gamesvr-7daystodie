# escape=`

FROM lacledeslan/steamcmd:linux as seven-builder

ARG SKIP_STEAMCMD=false

# Copy cached build files (if any)
COPY --chown=SteamCMD:root  ./linux/steamcmd-cache /output

# Download 7 Days to Die Dedicated Server via SteamCMD
RUN if [ "$SKIP_STEAMCMD" = true ] ; then `
        echo "\n\nSkipping SteamCMD install -- using only contents from steamcmd-cache\n\n"; `
    else `
        echo "\n\nDownloading 7 Days to Die Dedicated Server via SteamCMD"; `
        /app/steamcmd.sh `
            +force_install_dir /output  `
            +login anonymous `
            +app_update 294420 validate `
            +quit; `
    fi;

#=======================================================================
FROM debian:bullseye-slim

ARG BUILDNODE=unspecified
ARG SOURCE_COMMIT=unspecified

LABEL org.opencontainers.image.source https://github.com/LacledesLAN/gamesvr-7daystodie
LABEL org.opencontainers.image.title "7 Days to Die Dedicated Server"
LABEL org.opencontainers.image.url https://github.com/LacledesLAN/README.1ST
LABEL org.opencontainers.image.vendor "Laclede's LAN"

RUN dpkg --add-architecture i386 &&`
    apt-get update && apt-get install -y `
        ca-certificates lib32gcc-s1 libc6-i386 lib32stdc++6 locales locales-all tmux xmlstarlet &&`
    apt-get clean &&`
    echo "LC_ALL=en_US.UTF-8" >> /etc/environment &&`
    rm -rf /var/lib/apt/lists/*;

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8

# Set up Enviornment
RUN useradd --home /app --gid root --system 7DaysToDie &&`
    mkdir -p /app/ll-tests &&`
    chown 7DaysToDie:root -R /app;

# `RUN true` lines are work around for https://github.com/moby/moby/issues/36573
COPY --chown=7DaysToDie:root --from=seven-builder /output /app
RUN true

COPY --chown=7DaysToDie:root ./linux/ll-tests /app/ll-tests

RUN chmod +x /app/ll-tests/*.sh;

USER 7DaysToDie

WORKDIR /app

CMD ["/bin/bash"]

ONBUILD USER root
