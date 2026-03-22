FROM ubuntu:24.04 AS download

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ARG OBSIDIAN_VERSION=1.12.4
RUN wget -q "https://github.com/obsidianmd/obsidian-releases/releases/download/v${OBSIDIAN_VERSION}/Obsidian-${OBSIDIAN_VERSION}.AppImage" -O /opt/obsidian.AppImage \
    && chmod +x /opt/obsidian.AppImage \
    && cd /opt && /opt/obsidian.AppImage --appimage-extract \
    && mv /opt/squashfs-root /opt/obsidian \
    && rm /opt/obsidian.AppImage \
    && chmod -R a+rx /opt/obsidian \
    && chmod a+x /opt/obsidian/obsidian

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies only
RUN apt-get update && apt-get install -y --no-install-recommends \
    xvfb \
    libgtk-3-0 \
    libnotify4 \
    libnss3 \
    libxss1 \
    libasound2t64 \
    libgbm1 \
    xdg-utils \
    libsecret-1-0 \
    libdrm2 \
    socat \
    && rm -rf /var/lib/apt/lists/*

COPY --from=download /opt/obsidian /opt/obsidian

ARG UID=1000
ARG GID=1000
RUN userdel -r ubuntu 2>/dev/null; groupdel ubuntu 2>/dev/null; \
    groupadd -g ${GID} obsidian && \
    useradd -m -s /bin/bash -u ${UID} -g obsidian obsidian

# Create vault mount point and X11 socket directory
RUN mkdir -p /vault && chown obsidian:obsidian /vault && \
    mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix

# Create startup script
COPY entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD pgrep -f "obsidian" > /dev/null || exit 1

USER obsidian
WORKDIR /home/obsidian

ENTRYPOINT ["/opt/entrypoint.sh"]
