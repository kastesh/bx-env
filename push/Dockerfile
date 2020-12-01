# push/Dockerfile
FROM node:10 as bitrixenv

RUN mkdir -p /opt/push-server

ADD https://repos.1c-bitrix.ru/yum-testing/push-server-2.0.8.tar.gz /opt/push-server/push-server.tar.gz

WORKDIR /opt/push-server

RUN tar xzvvf push-server.tar.gz && \
    rm -f push-server.tar.gz

RUN npm install --production

FROM node:10-alpine

VOLUME /var/log/push-server

WORKDIR /opt/push-server

RUN mkdir -p /usr/local/bin &&  \
    apk add --no-cache bash && \
    apk add --no-cache gettext libintl && \
    mv /usr/bin/envsubst /usr/local/bin/envsubst

COPY --from=bitrixenv /opt/push-server /opt/push-server

COPY docker-entrypoint.sh /usr/local/bin/
COPY etc/push-server-pub-__PORT__.json /etc/push-server/push-server-pub-__PORT__.json
COPY etc/push-server-sub-__PORT__.json /etc/push-server/push-server-sub-__PORT__.json

ENV MODE pub
ENV SECURITY_KEY ChangeThisKey
ENV REDIS_HOST redis
ENV REDIS_PORT 6379
ENV LISTEN_PORT 9010
ENV LISTEN_HOSTNAME 0.0.0.0

RUN chmod 0755 /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
