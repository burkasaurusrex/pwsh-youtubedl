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
	cmake \
 	build-essential \
  	pkg-config \
        libavcodec-dev \
	libavformat-dev \
 	libavutil-dev \
  	libswscale-dev \
	libswresample-dev \
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
    git clone https://github.com/gpac/gpac.git && \
    cd gpac && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release \
        -DENABLE_X11=OFF \
        -DENABLE_GL=OFF \
        -DENABLE_SDL=OFF \
        -DENABLE_XVIDEO=OFF \
        -DENABLE_OPENGL_ES=OFF \
        -DENABLE_VULKAN=OFF \
        -DENABLE_OPENJPEG=OFF \
        -DENABLE_XVID=OFF \
        -DENABLE_PLAYER=OFF \
        -DENABLE_SPIDERMONKEY=OFF \
        -DENABLE_JS=OFF \
        -DENABLE_LUA=OFF \
        -DENABLE_XSLT=OFF \
        -DENABLE_ALSA=OFF \
        -DENABLE_PULSE=OFF \
        -DENABLE_OSS_AUDIO=OFF \
        -DENABLE_DIRECTSOUND=OFF \
        -DENABLE_COREAUDIO=OFF \
        -DENABLE_FFMPEG=ON \
        -DENABLE_ZLIB=ON \
        -DENABLE_PNG=ON \
        -DENABLE_JPEG=ON \
        -DENABLE_TIFF=ON \
        -DENABLE_FREETYPE=ON \
        -DENABLE_TTF=ON \
        -DENABLE_FONTCONFIG=ON \
        -DENABLE_GPACPARSER=ON && \
    make -j$(nproc) && make install && \
    rm -rf /tmp/* /var/lib/apt/lists/*

# ---- Build CCExtractor ----
FROM base AS builder-ccextractor

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
    echo "DEB URL: $DEB_URL" && \
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
