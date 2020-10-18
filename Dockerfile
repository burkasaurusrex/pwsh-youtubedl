FROM mcr.microsoft.com/powershell:lts-debian-buster-slim
VOLUME /root/.local/share/powershell/Modules
COPY . /
RUN \
	echo "**** install runtime packages ****" && \
		apt-get update && \
		apt-get upgrade -y --no-install-recommends && \
		apt-get install -y --no-install-recommends \
			bash \
			curl \
			ffmpeg \
			python3 \
			python3-pip \
			streamlink \
			tzdata \
			webp && \
	echo "**** pip check ****" && \
		pip3 --version && \
	echo "**** install python packages ****" && \
		pip3 install --no-cache-dir --upgrade --requirement /requirements.txt && \
	echo "**** basic youtube-dl check ****" && \
		youtube-dl --version
ENTRYPOINT ["pwsh", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'Continue'; $verbosePreference='Continue';"]