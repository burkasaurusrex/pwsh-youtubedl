# ---- Arguments ----
ARG DEBIAN_VERSION=bookworm

# ---- Base Image ----
FROM mcr.microsoft.com/powershell:debian-${DEBIAN_VERSION} AS base

# ---- Volumes ----
VOLUME /root/.local/share/powershell/Modules

# ---- Environment Variables ----
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV TARGET_ARCH=${DEBIAN_VERSION}_amd64
ENV PATH="$PATH:/usr/lib/jellyfin-ffmpeg"
ENV LD_LIBRARY_PATH=/usr/lib/jellyfin-ffmpeg:/usr/local/lib

# ---- Base runtime packages (headless) ----
RUN set -eux && \
    echo 'APT::Install-Recommends "0";' >| /etc/apt/apt.conf && \
    echo 'APT::Install-Suggests "0";' >> /etc/apt/apt.conf && \
    apt-get update && \
    apt-get upgrade -y --allow-remove-essential && \
    apt-get install -y --allow-remove-essential \
        apt-transport-https \
        aria2 \
        bash \
        curl \
        intel-media-va-driver \
        libva2 \
        libva-drm2 \
        locales \
        mediainfo \
        python3 \
        python3-pip \
        python3-setuptools \
        sqlite3 \
        tzdata \
        unzip \
        webp \
        zip \
        # Known fonts for subtitle and emoji support
        fonts-liberation \
        fonts-dejavu-core \
        fonts-noto-core \
        fonts-noto-color-emoji && \
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
    # Test Jellyfin-ffmpeg binaries immediately
    ffmpeg -version && \
    # Install mkvtoolnix
    cd /usr/share/keyrings && \
    curl -O https://mkvtoolnix.download/gpg-pub-moritzbunkus.gpg && \
    cd / && \
    echo "deb [signed-by=/usr/share/keyrings/gpg-pub-moritzbunkus.gpg] https://mkvtoolnix.download/debian/ ${DEBIAN_VERSION} main" >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends mkvtoolnix && \
    # Test mkvtoolnix binaries immediately
    mkvmerge --version && \
    mkvinfo --version && \
    mkvextract --version && \
    mkvpropedit --version && \
    # Final base cleanup
    rm -rf /tmp/* /var/lib/apt/lists/*

# ---- Build GPAC ----
FROM base AS builder-gpac

RUN set -eux && \
    apt-get update && \
    apt-get install -y --allow-remove-essential \
        git \
        autoconf \
        automake \
        libtool \
        build-essential \
        pkg-config \
        libavcodec-dev \
        libavformat-dev \
        libavutil-dev \
        libswresample-dev \
        libswscale-dev \
        libssl-dev \
        libpng-dev \
        libjpeg-dev \
        zlib1g-dev \
        libtiff-dev \
        libcurl4-openssl-dev \
        libfreetype6-dev \
        libfontconfig1-dev && \
    cd /tmp && \
    rm -rf gpac && \
    GPAC_TAG="v2.2.1" && \
    echo "GPAC tag: ${GPAC_TAG}" && \
    git clone --branch ${GPAC_TAG} https://github.com/gpac/gpac.git && \
    cd gpac && \
    ./configure \
        --disable-x11 \
        --use-ffmpeg="/usr/lib/jellyfin-ffmpeg" \
        --extra-ff-ldflags="-L/usr/lib/jellyfin-ffmpeg -Wl,-rpath,/usr/lib/jellyfin-ffmpeg" \
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
    rm -rf /tmp/* /var/lib/apt/lists/*

# ---- Build CCExtractor ----
FROM builder-gpac AS builder-ccextractor

RUN set -eux && \
    apt-get update && \
    apt-get install -y --allow-remove-essential \
        git \
        autoconf \
        automake \
        libtool \
        build-essential \
        pkg-config \
        libssl-dev \
        libcurl4-openssl-dev \
        libfreetype6-dev \
        libfontconfig1-dev \
        libpng-dev \
        zlib1g-dev \
        libtesseract-dev \
        libleptonica-dev && \
    cd /tmp && \
    rm -rf ccextractor && \
    git clone https://github.com/CCExtractor/ccextractor.git && \
    cd ccextractor/linux && \
    ./autogen.sh && \
    PKG_CONFIG_PATH=/usr/lib/jellyfin-ffmpeg/pkgconfig ./configure \
        --enable-hardsubx \
        --enable-ocr \
        --enable-ffmpeg \
        --without-rust && \
    make -j$(nproc) && \
    make install && \
    rm -rf /tmp/* /var/lib/apt/lists/*

# ---- Final Image ----
FROM base AS final

COPY requirements.txt /requirements.txt
COPY --from=builder-gpac /usr/local /usr/local
COPY --from=builder-ccextractor /usr/local /usr/local

RUN set -eux && \
    # Test binaries
    MP4Box -version && \
    gpac -h && \
    ccextractor --version && \
    # Install Python requirements
    pip3 install --no-cache-dir --upgrade --requirement /requirements.txt --break-system-packages && \
    streamlink --version && \
    youtube-dl --version

# Final entrypoint
ENTRYPOINT ["pwsh", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'Continue'; $verbosePreference='Continue';"]
