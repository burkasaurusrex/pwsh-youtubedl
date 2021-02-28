FROM mcr.microsoft.com/powershell:lts-debian-buster-slim
VOLUME /root/.local/share/powershell/Modules
COPY . /
RUN \
	echo "**** set up apt ****" && \
		echo 'APT::Default-Release "buster";' >| /etc/apt/apt.conf && \
		echo 'APT::Install-Recommends "0";' >> /etc/apt/apt.conf && \
		echo 'APT::Install-Suggests "0";' >> /etc/apt/apt.conf && \
		echo 'deb http://deb.debian.org/debian buster main' >| /etc/apt/sources.list && \
		echo 'deb http://deb.debian.org/debian testing main' >> /etc/apt/sources.list && \
		apt-get update && \
	echo "**** remove gui ****" && \
		apt-get purge '*x11*' libwayland-client0 libwayland-server0 && \
	echo "**** install buster packages ****" && \
		apt-get upgrade -y && \
		apt-get install -y \
			bash \
			curl \
			mediainfo \
			python3 \
			python3-pip \
			streamlink \
			tzdata \
			webp && \
	echo "**** install testing packages ****" && \
		apt-get -t testing install -y \
			ffmpeg && \	
	echo "**** ffmpeg check ****" && \
		ffmpeg -version && \
	echo "**** pip check ****" && \
		pip3 --version && \
	echo "**** install python packages ****" && \
		pip3 install --no-cache-dir --upgrade --requirement /requirements.txt && \
	echo "**** basic youtube-dl check ****" && \
		youtube-dl --version && \
	echo "**** cleanup ****" && \
		apt-get autoremove -y && \
		apt-get clean && \
		rm -rf \
			/tmp/* \
			/var/tmp/* \
			/var/lib/apt/lists/*
ENTRYPOINT ["pwsh", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'Continue'; $verbosePreference='Continue';"]