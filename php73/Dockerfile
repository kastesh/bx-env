FROM php:7.3-fpm

ARG APCU_VERSION=5.1.19

ARG CONTAINER_GID=1000
ARG CONTAINER_UID=1000
ARG CONTAINER_USER=bitrix
ARG CONTAINER_GROUP=bitrix

ARG XDEBUG_IP

COPY ./conf.d /usr/local/etc/php/conf.d/
COPY ./php-fpm.d /usr/local/etc/php-fpm.d/
COPY ./exim/update-exim4.conf.conf /etc/exim4/

RUN apt-get update \
    && apt-get install -y vim exim4 zip unzip default-mysql-client \
    && echo "syntax on" > ~/.vimrc \
    && apt-get -y install \
        libmagickwand-dev \
        libjpeg62-turbo-dev \
        libfreetype6-dev \
        libmemcached-dev \
        libicu-dev \
        libzip-dev \
        zlib1g-dev \
        libpng-dev \
        libxml2-dev \
        --no-install-recommends \
    && pecl install imagick \
    && docker-php-ext-enable imagick \
    && pecl install apcu-${APCU_VERSION} \
    && docker-php-ext-enable apcu \
    && pecl install memcached \
    && docker-php-ext-enable memcached \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-install mysqli pdo_mysql opcache exif intl sockets bz2 zip \
    && docker-php-ext-configure opcache --enable-opcache \
    && rm -rf /tmp/* /var/cache/apk/* /var/lib/apt/lists/* 

RUN groupadd -g ${CONTAINER_GID} ${CONTAINER_GROUP} && \
    useradd -u ${CONTAINER_UID} -g ${CONTAINER_GID} ${CONTAINER_USER}

RUN chmod -R 777 /usr/local/etc/php/ && \
    chown -R ${CONTAINER_USER} /usr/local/etc/php/ 

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod 0755 /usr/local/bin/docker-entrypoint.sh

COPY ./bitrix /tmp/bitrix/

USER bitrix:bitrix

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

CMD ["php-fpm"]
