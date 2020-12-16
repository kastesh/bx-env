FROM ubuntu:focal

ENV TZ=Europe/Moscow
WORKDIR /root

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN DEBIAN_FRONTEND=noninteractive apt-get update -y && \
    apt-get -y install python3 python3-pip python3-venv curl && \
    apt-get -y install apt-transport-https ca-certificates gnupg-agent software-properties-common && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - && \
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable" && \
    apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose && \
    apt-get -y clean


RUN git clone https://github.com/kastesh/bx-env

