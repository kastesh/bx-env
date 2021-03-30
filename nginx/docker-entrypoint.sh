#!/bin/bash

BX_WORKDIR=/etc/nginx
BX_TEMPLATE=bx.template
BX_TARGETDIR=sites-enabled
BX_INCLUDES=includes
WWW_DIR=/var/www/public_html

TEMPLATE="${BX_WORKDIR}/${BX_TEMPLATE}"

PHP_VERS=(php71 php72 php73 php74 php80)
MYSQL_VERS=(mysql57 mysql80)


create_config(){
    f="${1}"

    [[ -z $f ]] && return 1

    echo "Processing $f"

    fname=$(basename $f)
    fdir=$(dirname $f)

    if [[ $f =~ "/" ]]; then
        php_version=$(echo ${f} | \
            awk -F'/' '{print $(NF-2)}')
        mysql_version=$(echo ${f} | \
            awk -F'/' '{print $(NF-1)}')
    fi

    if [[ -z $php_version ]]; then
        php_version=php
    fi

    # filename contains dot or not defined local domain
    if [[ ${fname} =~ "." || ${BX_DEFAULT_LOCAL_DOMAIN} == '' ]]; then 
        HOST=${fname}
    else
        HOST="${fname}.${BX_DEFAULT_LOCAL_DOMAIN}"
    fi

    if [[ ${HOST} == ${BX_DEFAULT_HOST} ]]; then 
        DEFAULT=" default_server" 
    else
        DEFAULT=""
    fi

    OUTPUT="${BX_WORKDIR}/${BX_TARGETDIR}/${HOST}.conf"

    [[ -f ${OUTPUT} ]] && return 1

    touch "${OUTPUT}" && \
        sed -e "s:%HOST%:${HOST}:g; \
            s:%NAME%:${f}:g; \
            s:%DEFAULT%:${DEFAULT}:g; \
            s:%PHPFPM%:${php_version}:g;" \
       "${TEMPLATE}" > ${OUTPUT}
    echo "Create config: $OUTPUT"

    sed -i "s:%PUB_HOST%:$BX_PUSH_PUB_HOST:g; \
            s:%PUB_PORT%:$BX_PUSH_PUB_PORT:g; \
            s:%SUB_HOST%:$BX_PUSH_SUB_HOST:g; \
            s:%SUB_PORT%:$BX_PUSH_SUB_PORT:g" \
            "${BX_WORKDIR}/${BX_INCLUDES}/push.conf"
    echo "Update ${BX_WORKDIR}/${BX_INCLUDES}/push.conf"
 
    return 0
}

########################
# create nginx configs
########################
if [[ ${BX_HOST_AUTOCREATE} == 1 ]]; then

    # www directory doesn't exists => exit
    pushd ${WWW_DIR} >/dev/null 2>&1 || exit

    # create site-enable directory
    [[ ! (-d "${BX_WORKDIR}/${BX_TARGETDIR}") ]] &&\
        mkdir -p "${BX_WORKDIR}/${BX_TARGETDIR}"

    for f in *; do

        # site is a subdirectroy in public_html
        [[ ! (-d ${f}) ]] && continue
        
        # defined php 
        if [[ $(printf "%s\n" "${PHP_VERS[@]}" | \
            grep -cP "^$f$") -gt 0 ]]; then

            # pushd php71
            pushd $f >/dev/null 2>&1 || exit
            for pf in *; do
            
                if [[ $(printf "%s\n" "${MYSQL_VERS[@]}" | \
                    grep -cP "^$pf$") -gt 0  ]]; then

                    # pushd mysql80
                    pushd $pf >/dev/null 2>&1 || exit

                    # test.site
                    for vf in *; do
                        [[ ! ( -d $vf ) ]] && continue

                        create_config "${f}/${pf}/${vf}" 
                    done

                    popd >/dev/null 2>&1 # return php71
                fi
            done
            popd >/dev/null 2>&1  # return basedir 
            continue
        fi
        create_config "${f}"

    done

    popd >/dev/null 2>&1

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
