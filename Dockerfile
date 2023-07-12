FROM mcr.microsoft.com/powershell:debian-bullseye-slim
# FROM mcr.microsoft.com/powershell:preview-debian-bullseye-slim
VOLUME /root/.local/share/powershell/Modules
COPY . /
RUN \
	echo "**** set up apt ****" && \
		echo 'APT::Default-Release "stable";' >| /etc/apt/apt.conf && \
		echo 'APT::Install-Recommends "0";' >> /etc/apt/apt.conf && \
		echo 'APT::Install-Suggests "0";' >> /etc/apt/apt.conf && \
		echo 'deb http://deb.debian.org/debian stable main' >| /etc/apt/sources.list && \
		echo 'deb http://deb.debian.org/debian testing main' >> /etc/apt/sources.list && \
		apt-get update && \
	echo "**** install buster packages ****" && \
		apt-get upgrade -y --allow-remove-essential && \
		apt-get install -y --allow-remove-essential \
			aria2 \
			bash \
   			build-essential \
			curl \
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
	echo "**** install testing packages ****" && \
		apt-get -t testing install -y --allow-remove-essential \
			ffmpeg \
			mediainfo && \	
	echo "**** ffmpeg check ****" && \
		ffmpeg -version && \			
	echo "**** set up msft package signing key and install dotnet ****" && \
	 	cd /tmp && \
		curl -O https://packages.microsoft.com/config/debian/11/packages-microsoft-prod.deb && \
		cd / && \
		dpkg -i /tmp/packages-microsoft-prod.deb && \
		apt-get update && \
		apt-get install -y apt-transport-https && \
		apt-get update && \
		apt-get install -y dotnet-runtime-6.0 && \
	echo "**** dotnet check ****" && \
		dotnet --info && \
	echo "**** download mkvtoolnix key and install ****" && \
		cd /usr/share/keyrings && \
		curl -O https://mkvtoolnix.download/gpg-pub-moritzbunkus.gpg && \
		cd / && \
		echo 'deb [signed-by=/usr/share/keyrings/gpg-pub-moritzbunkus.gpg] https://mkvtoolnix.download/debian/ bullseye main' >> /etc/apt/sources.list && \
		echo 'deb-src [signed-by=/usr/share/keyrings/gpg-pub-moritzbunkus.gpg] https://mkvtoolnix.download/debian/ bullseye main' >> /etc/apt/sources.list && \
		apt-get update && \
		apt-get install -y mkvtoolnix && \
	echo "**** mkvtoolnix check ****" && \
		mkvmerge --version && \		
		mkvinfo --version && \
		mkvextract --version && \
		mkvpropedit --version && \
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
