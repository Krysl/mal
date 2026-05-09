FROM ubuntu:24.04
LABEL maintainer="Krysl <krysl@qq.com>"
LABEL org.opencontainers.image.source=https://github.com/kanaka/mal
LABEL org.opencontainers.image.description="mal test container: dart3"

##########################################################
# General requirements for testing or common across many
# implementations
##########################################################

RUN apt-get -y update

# Required for running tests
RUN apt-get -y install make python3
RUN ln -sf /usr/bin/python3 /usr/bin/python

# Some typical implementation and test requirements
RUN apt-get -y install curl libreadline-dev libedit-dev

##########################################################
# Specific implementation requirements
##########################################################

RUN apt-get -y install apt-transport-https wget gnupg
RUN wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub \
	| gpg --dearmor -o /usr/share/keyrings/dart.gpg
RUN echo 'deb [signed-by=/usr/share/keyrings/dart.gpg arch=amd64] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main' \
	| tee /etc/apt/sources.list.d/dart_stable.list
RUN apt-get -y update
# Pin to a stable 3.11.x release to satisfy package language version requirements.
RUN apt-get -y install dart=3.11.4-1

# Run dart with writable home/cache for arbitrary uid in docker run (-u <uid>).
ENV HOME=/tmp
ENV PUB_CACHE=/opt/dart-pub-cache
ENV IN_DOCKER=true
RUN mkdir -p /opt/dart-pub-cache /tmp/dart3-deps && chmod -R 777 /opt/dart-pub-cache /tmp/dart3-deps

# Pre-fetch dependencies into image cache so tests do not need to run pub get each time.
COPY pubspec.yaml /tmp/dart3-deps/
COPY pubspec.lock /tmp/dart3-deps/
RUN cd /tmp/dart3-deps && dart pub get
RUN chmod -R 777 /opt/dart-pub-cache

RUN mkdir -p /mal
WORKDIR /mal
