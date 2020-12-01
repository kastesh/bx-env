#!/bin/bash
# run push-server
# variables
# REDIS_HOST - redis host servername
# LISTEN_HOSTNAME - listen addresse
# LISTEN_PORT - listen port
# SECURITY_KEY - security key
# MODE - pub | sub
# RUN_DIR - temporary directory for service; default /tmp/push-server
# PUB_URI
# REST_URI  - pub service uri
# SUB_URI

export WORKDIR=/opt/push-server

export CONFIG_DIR=/etc/push-server
PUB_TMPL=$CONFIG_DIR/push-server-pub-__PORT__.json
SUB_TMPL=$CONFIG_DIR/push-server-sub-__PORT__.json
CONFIG=$CONFIG_DIR/config.json

export LOG_DIR=/var/log/push-server
[[ -z $RUN_DIR ]] && RUN_DIR=/tmp/push-server
export RUN_DIR

log(){
    msg="${1}"

    printf "%-16s: [%d]> %s\n" "$(date +%Y/%m/%dT%H:%M)" "$$" "$msg"
}

error() {
    msg="${1}"
    rtn="${2:-1}"

    log "$msg"
    exit $rtn
}

pushd $WORKDIR || \
	error "Cannot access $WORKDIR"

[[ -z $MODE ]] && \
	error "Not defind push-server mode environment variable: MODE"

[[ $MODE == "pub" || $MODE == "sub" ]] || \
	error "Incorrect value in MODE=$MODE variable."

if [[ $MODE == "pub" ]]; then
	TEMPLATE=$PUB_TMPL
    [[ -z $REST_URI ]] && REST_URI="/bitrix/rest/"
    [[ -z $PUB_URI ]] && PUB_URI="/bitrix/pub"
    export REST_URI
    export PUB_URI
elif [[ $MODE == "sub" ]]; then
	TEMPLATE=$SUB_TMPL
    [[ -z $SUB_URI ]] && SUB_URI="/bitrix/sub"
    export SUB_URI
fi

envsubst <$TEMPLATE >$CONFIG

node server.js --config $CONFIG
