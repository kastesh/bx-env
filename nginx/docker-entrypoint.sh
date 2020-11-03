#!/bin/bash

BX_WORKDIR=/etc/nginx
BX_TEMPLATE=bx.template
BX_TARGETDIR=sites-enabled
WWW_DIR=/var/www/public_html

TEMPLATE="${BX_WORKDIR}/${BX_TEMPLATE}"

########################
# create nginx configs
########################
if [[ ${BX_HOST_AUTOCREATE} == 1 ]]; then

    # www directory doesn't exists => exit
    cd ${WWW_DIR} || exit

    # create site-enable directory
    [[ ! (-d "${BX_WORKDIR}/${BX_TARGETDIR}") ]] &&\
        mkdir -p "${BX_WORKDIR}/${BX_TARGETDIR}"

    for f in *; do

        # site is a subdirectroy in public_html
        [[ ! (-d ${f}) ]] && continue

        # filename contains dot or not defined local domain
        if [[ ${f} =~ "." || ${BX_DEFAULT_LOCAL_DOMAIN} == '' ]]; then 
            HOST=${f}
        else
            HOST="${f}.${BX_DEFAULT_LOCAL_DOMAIN}"
        fi

        if [[ ${HOST} == ${BX_DEFAULT_HOST} ]]; then 
            DEFAULT=" default_server" 
        else
            DEFAULT=""
        fi

        OUTPUT="${BX_WORKDIR}/${BX_TARGETDIR}/${HOST}.conf"

        [[ -f ${OUTPUT} ]] && continue

        touch "${OUTPUT}" && \
            sed -e "s/%HOST%/${HOST}/; s/%NAME%/${f}/; s/%DEFAULT%/${DEFAULT}/" "${TEMPLATE}" > ${OUTPUT}
    done

fi
########################



set -e

[[ $DEBUG == true ]] && set -x

# allow arguments to be passed to nginx
if [[ ${1:0:1} = '-' ]]; then
    EXTRA_ARGS="$@"
    set --
elif [[ ${1} == nginx || ${1} == $(which nginx) ]]; then
    EXTRA_ARGS="${@:2}"
    set --
fi

# default behaviour is to launch nginx
if [[ -z ${1} ]]; then
    echo "Starting nginx..."
    exec $(which nginx) -g "daemon off;" ${EXTRA_ARGS}
else
    exec "$@"
fi
