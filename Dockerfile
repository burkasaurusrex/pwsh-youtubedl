FROM mcr.microsoft.com/powershell:lts-debian-buster-slim
VOLUME /root/.local/share/powershell/Modules
RUN \
	echo "**** install runtime packages ****" && \
		apt-get update && \
		apt-get upgrade -y && \
		apt-get install -y \
			bash \
			curl \
			ffmpeg \
			python3 \
			streamlink \
			tzdata && \
	echo "**** install youtube-dl ****" && \
		curl -L https://yt-dl.org/downloads/latest/youtube-dl -o /usr/local/bin/youtube-dl && \
		chmod a+rx /usr/local/bin/youtube-dl && \
	echo "**** basic youtube-dl check ****" && \
		youtube-dl --version
ENTRYPOINT ["pwsh", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'Continue'; $verbosePreference='Continue';"]