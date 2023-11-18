FROM mcr.microsoft.com/powershell:debian-bookworm
VOLUME /root/.local/share/powershell/Modules
COPY . /
RUN \
	echo "**** set up apt ****" && \
		echo 'APT::Install-Recommends "0";' >| /etc/apt/apt.conf && \
		echo 'APT::Install-Suggests "0";' >> /etc/apt/apt.conf && \
		apt-get update && \
	echo "**** install buster packages ****" && \
		apt-get upgrade -y --allow-remove-essential && \
		apt-get install -y --allow-remove-essential \
  			apt-transport-https \
			aria2 \
			bash \
   			build-essential \
			curl \
			ffmpeg \
   			mediainfo \
      			python3 \
			python3-pip \
			python3-setuptools \
			sqlite3 \
			tzdata \
			unzip \
			webp \
			zip && \
	echo "**** pip check ****" && \
		pip3 --version && \
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
	echo "**** cleanup ****" && \
		apt-get autoremove -y --allow-remove-essential && \
		apt-get clean && \
		rm -rf \
			/tmp/* \
			/var/tmp/* \
			/var/lib/apt/lists/*
ENTRYPOINT ["pwsh", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'Continue'; $verbosePreference='Continue';"]
