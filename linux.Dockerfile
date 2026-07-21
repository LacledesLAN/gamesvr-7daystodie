FROM lacledeslan/steamcmd AS steamcmd-builder

ARG ENABLE_STEAMCMD_CACHE=false

WORKDIR /output

RUN --mount=type=cache,id=7daystodie-steamcmd-cache,target=/mnt/steam-cache \
    echo "Downloading/Updating 7 Days to Die Dedicated Server via SteamCMD..." && \
    if [ "$ENABLE_STEAMCMD_CACHE" = "true" ]; then \
        INSTALL_DIR="/mnt/steam-cache"; \
    else \
        INSTALL_DIR="/output"; \
    fi && \
    # Run SteamCMD
    /app/steamcmd.sh \
        +force_install_dir "$INSTALL_DIR" \
        +login anonymous \
        +app_update 294420 validate \
        +quit && \
    # Only perform the sync step if the user explicitly opted into the cache
    if [ "$ENABLE_STEAMCMD_CACHE" = "true" ]; then \
        cp -r "$INSTALL_DIR"/. /output/; \
    fi


#---------------------------------
FROM debian:trixie-slim

ARG BUILD_DATE=unspecified \
    BUILD_NODE=unspecified \
    GIT_REVISION=unspecified

LABEL architecture="amd64" \
      com.lacledeslan.build-node="${BUILD_NODE}" \
      maintainer="Laclede's LAN <contact@lacledeslan.com>" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.description="7 Days to Die Dedicated Server" \
      org.opencontainers.image.revision="${GIT_REVISION}" \
      org.opencontainers.image.source="https://github.com/LacledesLAN/gamesvr-7daystodie" \
      org.opencontainers.image.vendor="Laclede's LAN"

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        locales && \
    sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen && \
    apt-get clean && \
    echo "LC_ALL=en_US.UTF-8" >> /etc/environment && \
    rm -rf /var/lib/apt/lists/*;

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8

# Set up Environment
RUN useradd --home /app --gid root --system 7DaysToDie && \
    mkdir -p /app && \
    chown 7DaysToDie:root -R /app;

COPY --chown=7DaysToDie:root --from=steamcmd-builder /output /app

USER 7DaysToDie

WORKDIR /app

CMD ["/bin/bash"]

ONBUILD USER root
