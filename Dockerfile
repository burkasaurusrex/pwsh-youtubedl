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
ENV PATH="$PATH:/usr/local/bin"
ENV LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/local/lib"

# ---- Volumes ----
VOLUME /root/.local/share/powershell/Modules

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
    # Final base cleanup
    rm -rf /tmp/* /var/lib/apt/lists/*

# ---- Build Jellyfin-FFmpeg ----
FROM base AS builder-ffmpeg-jellyfin

RUN set -eux && \
    apt-get update && \
    apt-get install -y --allow-remove-essential \
        git \
        autoconf \
        automake \
        libtool \
        build-essential \
        pkg-config \
        yasm \
        nasm \
        libssl-dev \
        libfontconfig1-dev \
        libfreetype6-dev \
        libfribidi-dev \
        libass-dev \
        libvpx-dev \
        libx264-dev \
        libx265-dev \
        libnuma-dev \
        libvpl-dev \
        libva-dev \
        libvdpau-dev \
        libxcb1-dev \
        libxcb-shm0-dev \
        libxcb-xfixes0-dev \
        zlib1g-dev && \
    cd /tmp && \
    rm -rf jellyfin-ffmpeg && \
    git clone --depth 1 https://github.com/jellyfin/jellyfin-ffmpeg.git && \
    cd jellyfin-ffmpeg && \
    ./configure \
        --prefix=/usr/local \
        --pkg-config-flags="--static" \
        --extra-cflags="-I/usr/local/include" \
        --extra-ldflags="-L/usr/local/lib" \
        --extra-libs="-lpthread -lm" \
        --enable-gpl \
        --enable-version3 \
        --enable-shared \
        --enable-pic \
        --enable-libfreetype \
        --enable-libfribidi \
        --enable-libass \
        --enable-libvpx \
        --enable-libx264 \
        --enable-libx265 \
        --enable-libvpl \
        --enable-libva \
        --enable-libvdpau \
        --enable-libxcb \
        --enable-libxcb-shm \
        --enable-libxcb-xfixes && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    rm -rf /tmp/* /var/lib/apt/lists/*

# ---- Build GPAC ----
FROM builder-ffmpeg-jellyfin AS builder-gpac

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
    PKG_CONFIG_PATH=/usr/local/lib/pkgconfig ./configure \
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
    PKG_CONFIG_PATH=/usr/local/lib/pkgconfig ./configure \
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
COPY --from=builder-ffmpeg-jellyfin /usr/local /usr/local
COPY --from=builder-gpac /usr/local /usr/local
COPY --from=builder-ccextractor /usr/local /usr/local

RUN set -eux && \
    # Test binaries
    ffmpeg -version && \
    ffprobe -version && \
    MP4Box -version && \
    gpac -h && \
    ccextractor --version && \
    # Install Python requirements
    pip3 install --no-cache-dir --upgrade --requirement /requirements.txt --break-system-packages && \
    streamlink --version && \
    youtube-dl --version

# Final entrypoint
ENTRYPOINT ["pwsh", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'Continue'; $verbosePreference='Continue';"]
