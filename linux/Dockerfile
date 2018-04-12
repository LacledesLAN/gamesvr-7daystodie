# escape=`

FROM lacledeslan/steamcmd:linux as seven-builder

ARG SKIP_STEAMCMD=false

# Copy cached build files (if any)
COPY --chown=SteamCMD:root  ./steamcmd-cache /output

# Download 7 Days to Die Dedicated Server via SteamCMD
RUN if [ "$SKIP_STEAMCMD" = true ] ; then `
        echo "\n\nSkipping SteamCMD install -- using only contents from steamcmd-cache\n\n"; `
    else `
        echo "\n\nDownloading 7 Days to Die Dedicated Server via SteamCMD"; `
        /app/steamcmd.sh `
            +login anonymous `
            +force_install_dir /output  `
            +app_update 294420 validate `
            +quit; `
    fi;

#=======================================================================
FROM debian:stable-slim

ARG BUILDNODE=unspecified
ARG SOURCE_COMMIT=unspecified

HEALTHCHECK NONE

RUN dpkg --add-architecture i386 &&`
    apt-get update && apt-get install -y `
        ca-certificates lib32gcc1 libc6-i386 lib32stdc++6 locales locales-all tmux xmlstarlet &&`
    apt-get clean &&`
    echo "LC_ALL=en_US.UTF-8" >> /etc/environment &&`
    rm -rf /var/lib/apt/lists/*;

ENV LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8 LC_ALL=en_US.UTF-8

LABEL com.lacledeslan.build-node=$BUILDNODE `
      org.label-schema.schema-version="1.0" `
      org.label-schema.url="https://github.com/LacledesLAN/README.1ST" `
      org.label-schema.vcs-ref=$SOURCE_COMMIT `
      org.label-schema.vendor="Laclede's LAN" `
      org.label-schema.description="7 Days to Die Dedicated Server" `
      org.label-schema.vcs-url="https://github.com/LacledesLAN/gamesvr-7daystodie"

# Set up Enviornment
RUN useradd --home /app --gid root --system 7DaysToDie &&`
    mkdir -p /app/ll-tests &&`
    chown 7DaysToDie:root -R /app;

COPY --chown=7DaysToDie:root --from=seven-builder /output /app

COPY --chown=7DaysToDie:root ./ll-tests /app/ll-tests

RUN chmod +x /app/ll-tests/*.sh;

USER 7DaysToDie

WORKDIR /app

CMD ["/bin/bash"]

ONBUILD USER root
