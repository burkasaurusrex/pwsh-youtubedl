# ---- Arguments ----
ARG DEBIAN_VERSION=bookworm

# ---- Base Image ----
FROM mcr.microsoft.com/powershell:debian-${DEBIAN_VERSION} AS base

# ---- Arguments ----
ARG DEBIAN_VERSION

# ---- Environment Variables ----
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV DEBIAN_VERSION=${DEBIAN_VERSION}
ENV TARGET_ARCH=${DEBIAN_VERSION}_amd64
ENV PATH="$PATH:/usr/lib/jellyfin-ffmpeg"
ENV LD_LIBRARY_PATH="/usr/lib/jellyfin-ffmpeg:/usr/local/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# ---- Volumes ----
VOLUME /root/.local/share/powershell/Modules

# ---- Base runtime packages ----
RUN set -eux && \
    echo 'APT::Install-Recommends "0";' >| /etc/apt/apt.conf && \
    echo 'APT::Install-Suggests "0";' >> /etc/apt/apt.conf && \
    apt-get update && \
    apt-get upgrade -y --allow-remove-essential && \
    apt-get install -y --no-install-recommends \
        apt-transport-https \
        aria2 \
        bash \
        curl \
        fonts-dejavu-core \
        intel-media-va-driver \
        libva-drm2 \
        libva2 \
        locales \
        mediainfo \
        python3 \
        python3-pip \
        python3-setuptools \
        sqlite3 \
        tzdata \
        unzip \
        webp \
        zip && \
    # Configure locale
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen && \
    update-locale LANG=en_US.UTF-8 && \
    # Install Jellyfin-ffmpeg
    DEB_URL=$(curl -s https://api.github.com/repos/jellyfin/jellyfin-ffmpeg/releases/latest \
        | grep 'browser_download_url' \
        | grep "${TARGET_ARCH}\.deb" \
        | head -n 1 \
        | sed -E 's/.*"([^"]+)".*/\1/') && \
    echo "jellyfin-ffmpeg URL: $DEB_URL" && \
    curl -L -o /tmp/jellyfin-ffmpeg.deb "$DEB_URL" && \
    apt-get install -y /tmp/jellyfin-ffmpeg.deb && \
    rm -f /tmp/jellyfin-ffmpeg.deb && \
    # Fix references
    echo "/usr/local/lib" > /etc/ld.so.conf.d/local.conf && \
    echo "/usr/lib/jellyfin-ffmpeg" > /etc/ld.so.conf.d/jellyfin-ffmpeg.conf && \
    ldconfig && \
    ffmpeg -version && \
    # Install mkvtoolnix
    cd /usr/share/keyrings && \
    curl -O https://mkvtoolnix.download/gpg-pub-moritzbunkus.gpg && \
    cd / && \
    echo "deb [signed-by=/usr/share/keyrings/gpg-pub-moritzbunkus.gpg] https://mkvtoolnix.download/debian/ ${DEBIAN_VERSION} main" > /etc/apt/sources.list.d/mkvtoolnix.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends mkvtoolnix && \
    mkvmerge --version && \
    mkvextract --version && \
    mkvinfo --version && \
    rm -rf /tmp/* /var/lib/apt/lists/*

# ---- Build GPAC ----
FROM base AS builder-gpac

ARG GPAC_TAG=v2.2.1

RUN set -eux && \
    apt-get update && \
    apt-get install -y --allow-remove-essential \
        autoconf \
        automake \
        build-essential \
        ffmpeg \
        git \
        libavcodec-dev \
        libavformat-dev \
        libavutil-dev \
        libcurl4-openssl-dev \
        libfreetype6-dev \
        libfontconfig1-dev \
        libjpeg-dev \
        libleptonica-dev \
        libpng-dev \
        libssl-dev \
        libswresample-dev \
        libswscale-dev \
        libtesseract-dev \
        libtiff-dev \
        libtool \
        pkg-config \
        zlib1g-dev && \
    cd /tmp && \
    rm -rf gpac && \
    echo "GPAC tag: ${GPAC_TAG}" && \
    git clone --branch ${GPAC_TAG} https://github.com/gpac/gpac.git && \
    cd gpac && \
    ./configure \
        --disable-x11 \
        --disable-gl \
        --disable-sdl \
        --disable-xvideo \
        --disable-opengl-es \
        --disable-vulkan \
        --disable-openjpeg \
        --disable-xvid \
        --disable-player \
        --disable-spidermonkey \
        --disable-js \
        --disable-lua \
        --disable-xslt \
        --disable-alsa \
        --disable-pulse \
        --disable-oss-audio \
        --disable-directsound \
        --disable-coreaudio \
        --enable-ffmpeg \
        --enable-zlib \
        --enable-png \
        --enable-jpeg \
        --enable-tiff \
        --enable-freetype \
        --enable-ttf \
        --enable-fontconfig \
        --enable-gpacparser \
        --enable-dev && \
    make -j$(nproc) && \
    make install && \
    # Strip binaries to save space
    strip /usr/local/bin/MP4Box || true && \
    strip /usr/local/bin/gpac || true && \
    strip /usr/local/lib/libgpac.so.* || true && \
    rm -rf /tmp/* /var/lib/apt/lists/*

# ---- Build CCExtractor ----
FROM builder-gpac AS builder-ccextractor

RUN set -eux && \
    cd /tmp && \
    rm -rf ccextractor && \
    git clone https://github.com/CCExtractor/ccextractor.git && \
    cd ccextractor/linux && \
    ./autogen.sh && \
    ./configure \
        --enable-hardsubx \
        --enable-ocr \
        --enable-ffmpeg \
        --without-rust && \
    make -j$(nproc) && \
    make install && \
    # Strip binary
    strip /usr/local/bin/ccextractor || true && \
    rm -rf /tmp/* /var/lib/apt/lists/*

# ---- Final Image ----
FROM base AS final

COPY requirements.txt /requirements.txt

# Selective COPY — only needed binaries and libs
# COPY --from=builder-gpac /usr/local/bin/gpac /usr/local/bin/gpac
# COPY --from=builder-gpac /usr/local/bin/MP4Box /usr/local/bin/MP4Box
# COPY --from=builder-gpac /usr/local/lib/libgpac.so.* /usr/local/lib/
# COPY --from=builder-gpac /usr/local/lib/gpac /usr/local/lib/gpac
# COPY --from=builder-ccextractor /usr/local/bin/ccextractor /usr/local/bin/ccextractor

# Add required shared libs and test dynamic linking
RUN set -eux && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        libavcodec59 \
        libavformat59 \
        libavutil57 \
        libfontconfig1 \
        libfreetype6 \
        libjpeg62-turbo \
        libpng16-16 \
        libssl3 \
        libswresample4 \
        libswscale6 \
        libtesseract5 \
        libleptonica-dev \
        zlib1g && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    # Test that all dynamic deps are resolved (pure shell, no grep)
    # ldd /usr/local/bin/MP4Box | awk '/not found/ { exit 1 }' && \
    # ldd /usr/local/bin/gpac | awk '/not found/ { exit 1 }' && \
    # ldd /usr/local/bin/ccextractor | awk '/not found/ { exit 1 }' && \
    # Test binaries
    # MP4Box -version && \
    # gpac -h && \
    # ccextractor --version && \
    # Install Python requirements
    pip3 install --no-cache-dir --upgrade --requirement /requirements.txt --break-system-packages && \
    yt-dlp --version

# Final entrypoint
ENTRYPOINT ["pwsh", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'Continue'; $verbosePreference='Continue';"]
