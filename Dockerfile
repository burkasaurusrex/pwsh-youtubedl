# ---- Arguments ----
ARG DEBIAN_VERSION=bookworm
ARG REPO_OWNER=jellyfin
ARG REPO_NAME=jellyfin-ffmpeg
ARG TARGET_ARCH=${DEBIAN_VERSION}_amd64

# ---- Base Image ----
FROM mcr.microsoft.com/powershell:debian-${DEBIAN_VERSION} AS base
VOLUME /root/.local/share/powershell/Modules
ENV PATH="$PATH:/usr/lib/jellyfin-ffmpeg"

# Copy project files early to make requirements.txt available in all stages
COPY . /

# Include jellyfin-ffmpeg in PATH
ENV PATH="$PATH:/usr/lib/jellyfin-ffmpeg"

# Base runtime packages (headless)
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
    # GPAC_TAG=$(curl -s https://api.github.com/repos/gpac/gpac/releases/latest | grep tag_name | cut -d '"' -f 4) && \
    GPAC_TAG="2.2.1" && \
    echo "GPAC tag: ${GPAC_TAG}" && \
    git clone --branch ${GPAC_TAG} https://github.com/gpac/gpac.git && \
    cd gpac && \
    ./configure \
        --disable-x11 \
        --use-ffmpeg=system \
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
	libavcodec-dev \
	libavformat-dev \
	libavutil-dev \
	libswresample-dev \
 	libswscale-dev \
        zlib1g-dev \
        libtesseract-dev \
        libleptonica-dev && \
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
    rm -rf /tmp/* /var/lib/apt/lists/*

# ---- Final Image ----
FROM base AS final

ARG DEBIAN_VERSION
ARG REPO_OWNER
ARG REPO_NAME
ARG TARGET_ARCH

# Explicitly copy requirements.txt for clarity
COPY requirements.txt /requirements.txt

RUN set -eux && \
    apt-get update && \
    # Install latest jellyfin-ffmpeg release
    DEB_URL=$(curl -s https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest \
        | grep 'browser_download_url' \
        | grep "${TARGET_ARCH}\.deb" \
        | head -n 1 \
        | sed -E 's/.*"([^"]+)".*/\1/') && \
    echo "jellyfin-ffmpeg URL: $DEB_URL" && \
    curl -L -o /tmp/${REPO_NAME}.deb "$DEB_URL" && \
    apt-get install -y /tmp/${REPO_NAME}.deb && \
    rm -f /tmp/${REPO_NAME}.deb && \
    # Test ffmpeg
    ffmpeg -version && \
    # Install mkvtoolnix from official repo
    cd /usr/share/keyrings && \
    curl -O https://mkvtoolnix.download/gpg-pub-moritzbunkus.gpg && \
    cd / && \
    echo "deb [signed-by=/usr/share/keyrings/gpg-pub-moritzbunkus.gpg] https://mkvtoolnix.download/debian/ ${DEBIAN_VERSION} main" >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends mkvtoolnix && \
    rm -rf /var/lib/apt/lists/*

# Copy GPAC and CCExtractor binaries from build stages
COPY --from=builder-gpac /usr/local /usr/local
COPY --from=builder-ccextractor /usr/local /usr/local

# Final validation and Python package install
RUN set -eux && \
    MP4Box -version && \
    ccextractor --version && \
    pip3 install --no-cache-dir --upgrade --requirement /requirements.txt --break-system-packages && \
    youtube-dl --version

# Final entrypoint
ENTRYPOINT ["pwsh", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'Continue'; $verbosePreference='Continue';"]
