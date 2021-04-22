# push/Dockerfile
FROM node:10 as bitrixenv

RUN mkdir -p /opt/push-server

ADD https://repos.1c-bitrix.ru/yum-testing/push-server-2.0.8.tar.gz /opt/push-server/push-server.tar.gz

WORKDIR /opt/push-server

RUN tar xzvvf push-server.tar.gz && \
    rm -f push-server.tar.gz

RUN npm install --production

FROM node:10-alpine

ARG MODE=pub
ARG SECURITY_KEY=ChangeThisKey
ARG REDIS_HOST=redis
ARG REDIS_PORT=6379
ARG LISTEN_PORT=9010
ARG CONTAINER_GID=1000
ARG CONTAINER_UID=1000
ARG CONTAINER_USER=node
ARG CONTAINER_GROUP=node

WORKDIR /opt/push-server

RUN mkdir -p /usr/local/bin &&  \
    apk add --no-cache bash && \
    apk add --no-cache gettext libintl && \
    mv /usr/bin/envsubst /usr/local/bin/envsubst

COPY --from=bitrixenv /opt/push-server /opt/push-server

RUN chown -R ${CONTAINER_UID}:${CONTAINER_GID} /opt/push-server && \
    [[ ! -d /tmp/push-server ]] && mkdir /tmp/push-server && \
    chown -R ${CONTAINER_UID}:${CONTAINER_GID} /tmp/push-server && \
    [[ ! -d /etc/push-server ]] && mkdir /etc/push-server

COPY docker-entrypoint.sh /usr/local/bin/
COPY etc/push-server-pub-__PORT__.json /etc/push-server/push-server-pub-__PORT__.json
COPY etc/push-server-sub-__PORT__.json /etc/push-server/push-server-sub-__PORT__.json

RUN chown -R ${CONTAINER_UID}:${CONTAINER_GID} /etc/push-server

RUN chmod 0755 /usr/local/bin/docker-entrypoint.sh

VOLUME /var/log/push-server

USER ${CONTAINER_USER}

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
