FROM nginx:stable

ARG CONTAINER_GID=1000
ARG CONTAINER_UID=1000
ARG CONTAINER_USER=bitrix
ARG CONTAINER_GROUP=bitrix


RUN groupadd -g ${CONTAINER_GID} ${CONTAINER_GROUP} && \
    useradd -u ${CONTAINER_UID} -g ${CONTAINER_GID} ${CONTAINER_USER}

RUN apt-get update && \
    apt-get install libcap2-bin -y && \
    setcap 'cap_net_bind_service=+ep' /usr/sbin/nginx && \
    rm -rf /var/lib/apt/lists/*

COPY ./etc/ /etc/nginx/
COPY ./bitrixenv_error/ /var/www/bitrixenv_error/

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod 0755 /usr/local/bin/docker-entrypoint.sh

RUN chown -R ${CONTAINER_UID}:${CONTAINER_GID} /var/cache/nginx && \
    chown -R ${CONTAINER_UID}:${CONTAINER_GID} /var/log/nginx && \
    mkdir /var/run/nginx && \
    chown -R ${CONTAINER_UID}:${CONTAINER_GID} /var/run/nginx && \
    chown -R ${CONTAINER_UID}:${CONTAINER_GID} /etc/nginx/ && \
    chown -R ${CONTAINER_UID}:${CONTAINER_GID} /usr/local/bin/docker-entrypoint.sh

USER ${CONTAINER_USER}

RUN envsubst < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["nginx"]
