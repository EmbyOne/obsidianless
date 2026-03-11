FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    xvfb \
    libgtk-3-0 \
    libnotify4 \
    libnss3 \
    libxss1 \
    libasound2t64 \
    libgbm1 \
    wget \
    ca-certificates \
    xdg-utils \
    libsecret-1-0 \
    libdrm2 \
    socat \
    && rm -rf /var/lib/apt/lists/*

# Download Obsidian AppImage
RUN wget -q "https://github.com/obsidianmd/obsidian-releases/releases/download/v1.12.4/Obsidian-1.12.4.AppImage" -O /opt/obsidian.AppImage \
    && chmod +x /opt/obsidian.AppImage \
    && cd /opt && /opt/obsidian.AppImage --appimage-extract \
    && mv /opt/squashfs-root /opt/obsidian \
    && rm /opt/obsidian.AppImage \
    && chmod -R a+rx /opt/obsidian \
    && chmod a+x /opt/obsidian/obsidian

# Create non-root user matching host uid/gid (clawdbot = 1000)
RUN userdel -r ubuntu 2>/dev/null || true; \
    groupadd -g 1000 obsidian 2>/dev/null || true; \
    useradd -m -s /bin/bash -u 1000 -o -g 1000 obsidian

# Create vault mount point
RUN mkdir -p /vault && chown obsidian:obsidian /vault

# Create startup script
COPY entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

USER obsidian
WORKDIR /home/obsidian

ENTRYPOINT ["/opt/entrypoint.sh"]
