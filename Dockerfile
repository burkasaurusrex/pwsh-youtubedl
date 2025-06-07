FROM mcr.microsoft.com/powershell:debian-bookworm
VOLUME /root/.local/share/powershell/Modules
COPY . /
# Set project variables
ENV REPO_OWNER=jellyfin
ENV REPO_NAME=jellyfin-ffmpeg
ENV TARGET_ARCH=bookworm_amd64

RUN \
	set -eux && \
	echo "**** set up apt ****" && \
		echo 'APT::Install-Recommends "0";' >| /etc/apt/apt.conf && \
		echo 'APT::Install-Suggests "0";' >> /etc/apt/apt.conf && \
		apt-get update && \
	echo "**** install buster packages ****" && \
		apt-get upgrade -y --allow-remove-essential && \
		apt-get install -y --allow-remove-essential \
  			# autoconf \
     			# automake \
  			apt-transport-https \
			aria2 \
			bash \
   			build-essential \
      			# clang \
      			# cmake \
			curl \
   			# dvb-apps \
			# ffmpeg \
   			# g++ \
   			# gcc \
      			# git \
	 		# liba52-0.7.4-dev \
    			# libasound2-dev \
    			# libavcodec-dev \
       			# libavformat-dev \
	  		# libavutil-dev \
     			# libcaca-dev \
      			# libclang-dev \
	 		# libcurl4-openssl-dev \
      			# libcurl4-gnutls-dev \
	 		# libfaad-dev \
	 		# libfreetype6-dev \
	 		# libjpeg62-turbo-dev \
	 		# libleptonica-dev \
    			# libmad0-dev \
       			# libnghttp2-dev \
       			# libogg-dev \
	  		# libopenjp2-7-dev \
    			# libpng-dev \
       			# libssl-dev \
       			# libswscale-dev \
	 		# libtesseract-dev \
    			# libtheora-dev \
    			# libvorbis-dev \
       			# libxvidcore-dev \
		    	intel-media-va-driver \
    			libva2 \
    			libva-drm2 \
    			vainfo \
   			mediainfo \
      			# pkg-config \
      			python3 \
			python3-pip \
			python3-setuptools \
			sqlite3 \
   			# tesseract-ocr \
      			# tesseract-ocr-dev \
			tzdata \
			unzip \
			webp \
   			# yasm \
   			# zlib1g-dev \
			zip && \  
	echo "**** pip check ****" && \
		pip3 --version && \
	echo "**** install jellyfin-ffmpeg ****" && \	
		DEB_URL=$(curl -s https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest \
		| grep 'browser_download_url' \
		| grep "${TARGET_ARCH}\.deb" \
		| head -n 1 \
		| sed -E 's/.*"([^"]+)".*/\1/') && \
		echo "DEB URL: $DEB_URL" && \
		curl -L -o /tmp/${REPO_NAME}.deb "$DEB_URL" && \
		apt-get install -y /tmp/${REPO_NAME}.deb && \
		rm -f /tmp/${REPO_NAME}.deb && \
  	echo "**** ffmpeg check ****" && \
		ffmpeg -version && \
	echo "**** download mkvtoolnix key and install ****" && \
		cd /usr/share/keyrings && \
		curl -O https://mkvtoolnix.download/gpg-pub-moritzbunkus.gpg && \
		cd / && \
		echo 'deb [signed-by=/usr/share/keyrings/gpg-pub-moritzbunkus.gpg] https://mkvtoolnix.download/debian/ bookworm main' >> /etc/apt/sources.list && \
		echo 'deb-src [signed-by=/usr/share/keyrings/gpg-pub-moritzbunkus.gpg] https://mkvtoolnix.download/debian/ bookworm main' >> /etc/apt/sources.list && \
		apt-get update && \
		apt-get install -y --allow-remove-essential mkvtoolnix && \
	echo "**** mkvtoolnix check ****" && \
		# mkvmerge --version && \
		# mkvinfo --version && \
		# mkvextract --version && \
		# mkvpropedit --version && \
	echo "**** install python packages ****" && \
		pip3 install --no-cache-dir --upgrade --requirement /requirements.txt --break-system-packages && \
	echo "**** basic youtube-dl check ****" && \
		youtube-dl --version && \
	echo "**** build gpac ****" && \
	 	# cd /tmp && \
		# git clone https://github.com/gpac/gpac.git && \
		# cd gpac && \
		# ./configure --disable-x11 --use-ffmpeg=system && \
		# make -j$(nproc) && \
		# make install && \
	echo "**** basic gpac test ****" && \
		# MP4Box -version && \
		# gpac -h && \
  	echo "**** build ccextractor ****" && \
		# cd /tmp && \
		# git clone https://github.com/CCExtractor/ccextractor.git && \
		# cd ccextractor/linux && \
		# ./autogen.sh && \
		# ./configure --enable-hardsubx --enable-ocr --enable-ffmpeg --without-rust && \
		# make -j$(nproc) && \
  		# make install && \
  	echo "**** basic ccextractor test ****" && \
		# ccextractor --version && \
	echo "**** cleanup ****" && \
		apt-get remove -y --allow-remove-essential \
  			autoconf \
     			automake \  	
   			build-essential \
      			clang \
      			cmake \	
			g++ \
   			gcc \
      			git \
			pkg-config \
   			python3-setuptools \
			yasm && \ 
		apt-get autoremove -y --allow-remove-essential && \
		apt-get clean && \
		rm -rf \
			/tmp/* \
			/var/tmp/* \
			/var/lib/apt/lists/*
ENTRYPOINT ["pwsh", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'Continue'; $verbosePreference='Continue';"]
