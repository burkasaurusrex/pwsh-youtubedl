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
	echo "**** set up msft package signing key ****" && \
		wget https://packages.microsoft.com/config/debian/10/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb && \
		dpkg -i /tmp/packages-microsoft-prod.deb && \
		apt-get update && \
		apt-get install -y apt-transport-https && \
		apt-get update && \
	echo "**** install buster packages ****" && \
		apt-get upgrade -y && \
		apt-get install -y \
			bash \
			curl \
			dotnet-sdk-5.0 \
			python3 \
			python3-pip \
			python3-setuptools \
			tzdata \
			webp && \
	echo "**** install testing packages ****" && \
		apt-get -t testing install -y \
			ffmpeg \
			mediainfo && \	
	echo "**** dotnet check ****" && \
		dotnet --list-sdks && \
	echo "**** install nuget packages ****" && \	
		dotnet add package Selenium.WebDriver && \
		dotnet add package Selenium.Support && \	
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