FROM mcr.microsoft.com/powershell:lts-debian-buster-slim
VOLUME /root/.local/share/powershell/Modules
COPY . /
RUN \
	echo "**** set up apt ****" && \
		echo 'APT::Default-Release "buster";' >| /etc/apt/apt.conf && \
		echo 'deb http://deb.debian.org/debian buster main' >| /etc/apt/sources.list && \
		echo 'deb http://deb.debian.org/debian testing main' >> /etc/apt/sources.list && \
		apt-get update && \
		apt-get upgrade -y --no-install-recommends && \
	echo "**** install buster packages ****" && \
		apt-get install -y --no-install-recommends \
			bash \
			curl \
			mediainfo \
			python3 \
			python3-pip \
			streamlink \
			tzdata \
			webp && \
	echo "**** install testing packages ****" && \
		apt-get -t testing install -y --no-install-recommends \
			ffmpeg && \	
	echo "**** ffmpeg check ****" && \
		ffmpeg -version && \
	echo "**** pip check ****" && \
		pip3 --version && \
	echo "**** install python packages ****" && \
		pip3 install --no-cache-dir --upgrade --requirement /requirements.txt && \
	echo "**** basic youtube-dl check ****" && \
		youtube-dl --version
ENTRYPOINT ["pwsh", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'Continue'; $verbosePreference='Continue';"]