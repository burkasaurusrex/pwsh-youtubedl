# FROM mcr.microsoft.com/powershell:debian-bullseye-slim
FROM mcr.microsoft.com/powershell:preview-debian-bullseye-slim
VOLUME /root/.local/share/powershell/Modules
COPY . /
RUN \
	echo "**** set up apt ****" && \
		echo 'APT::Default-Release "bullseye";' >| /etc/apt/apt.conf && \
		echo 'APT::Install-Recommends "0";' >> /etc/apt/apt.conf && \
		echo 'APT::Install-Suggests "0";' >> /etc/apt/apt.conf && \
		echo 'deb http://deb.debian.org/debian bullseye main' >| /etc/apt/sources.list && \
		echo 'deb http://deb.debian.org/debian testing main' >> /etc/apt/sources.list && \
		apt-get update && \
	echo "**** install buster packages ****" && \
		apt-get upgrade -y --allow-remove-essential && \
		apt-get install -y --allow-remove-essential \
			aria2 \
			bash \
			curl \
			python3 \
			python3-pip \
			python3-setuptools \
			tzdata \
			webp && \
	echo "**** install testing packages ****" && \
		apt-get -t testing install -y --allow-remove-essential \
			ffmpeg \
			mediainfo && \	
	echo "**** set up msft package signing key ****" && \
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
	echo "**** ffmpeg check ****" && \
		ffmpeg -version && \
	echo "**** pip check ****" && \
		pip3 --version && \
	echo "**** install python packages ****" && \
		pip3 install --no-cache-dir --upgrade --requirement /requirements.txt && \
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
