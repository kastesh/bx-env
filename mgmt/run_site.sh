#!/bin/bash
#set -x

PROGNAME=$(basename $0)
PROGPATH=$(dirname $0)

Color_Off='\033[0m'       # Text Reset
# Regular Colors
Black='\033[0;30m'        # Black
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White]]]]]]]]]'
Default="$Green"

log(){
    msg="${1}"

    echo -ne "$Default"
    [[ $VERBOSE -gt 0 ]] && \
        printf "%-16s: [%d]> %s\n" "$(date +%Y/%m/%dT%H:%M)" "$$" "$msg"
    echo -ne "$Color_Off"
    [[ -n $LOG ]] && \
        printf "%-16s: [%d]> %s\n" "$(date +%Y/%m/%dT%H:%M)" "$$" "$msg"  >> $LOG
}

error() {
    msg="${1}"
	rtn="${2:-1}"

    Default="$Red"
    VERBOSE=1
    log "$msg"

    [[ -f $TMP_FILE ]] && rm -f $TMP_FILE

    exit $rtn
}

usage(){
    rtn=${1:-0}

    echo "Usage: $PROGNAME -s site_name -p php_version -m mysql_version -a archive_name"
    echo "Options:"
    echo "-h  - show this help message"
    echo "-v  - enable verbose mode"
    echo "-s  - site name"
    echo "-p  - php version (default: php72)"
    echo "-m  - mysql version (default: mysql57)"
    echo "-a  - archive name (example: 20.200.300/b24)"
    echo "-c  - config file (default: $PROGPATH/CONFIG)"

    exit $rtn
}

status_docker(){
    service="${1}"
    TMP_FILE=$(mktemp /dev/shm/XXXXX_docker)

    docker ps > $TMP_FILE 2>&1
    if [[ $? -gt 0 ]]; then
        error "Docker cli return an error: $(cat $TMP_FILE)"
    fi

    DOCKER_STATUS=$(cat $TMP_FILE| awk '{printf "%s:%s\n", $1, $NF}')

    is_service=0
    if [[ -n $service ]]; then
        is_service=$(grep "$service" $TMP_FILE -c)
    fi
    log "$service: there is $is_service container"
    rm -f $TMP_FILE

    return $is_service
}

run_site(){
    # copy files
    DB="$DISTR_URL/${ARCHIVE}.sql"
    ARCH="$DISTR_URL/${ARCHIVE}.zip"

    SITE_DIR="$HTML_PATH/$PHPV/$MYV/$SITE"
    if [[ ! -d $SITE_DIR ]]; then
        mkdir -p $SITE_DIR
        pushd $SITE_DIR >/dev/null 2>&1
        log "Download ${ARCHIVE}.sql"
        curl -s "$DB" --output db.sql
        log "Download ${ARCHIVE}.zip"
        curl -s "$ARCH" --output files.zip
        log "Upload files to $SITE_DIR"
        popd >/dev/null 2>&1
    fi

    # run docker-composer with defind configs
    BASE_C=docker-compose.yml
    NGINX_C=docker-compose-nginx.yml
    PUSH_C=docker-compose-push.yml
    PHP_C=docker-compose-${PHPV}.yml
    MYSQL_C=docker-compose-${MYV}.yml
    NET_C=docker-compose-net.yml
    
    # if nginx or/and php is running we need to reboot them
    STOP_CMD=
    STOP_LIST=
    status_docker bx-nginx
    if [[ $? -gt 0 ]]; then
        pushd $PROJECT_DIR
        docker-compose -f $BASE_C -f $NET_C -f $NGINX_C stop nginx
        #docker-compose -f $BASE_C -f $NET_C -f $NGINX_C start nginx
        log "Restart nginx service"
        popd
    fi

    status_docker $PHPV
    if [[ $? -gt 0 ]]; then
        pushd $PROJECT_DIR
        # restartt php container
        docker-compose -f $BASE_C -f $NET_C -f $PHP_C stop $PHPV
        #docker-compose -f $BASE_C -f $NET_C -f $PHP_C start $PHPV
        log "Restart $PHPV service"
        popd
    fi

    pushd $PROJECT_DIR
    # if php and nginx not running we start them
    docker-compose -f $NET_C \
        -f $BASE_C \
        -f $MYSQL_C \
        -f $PUSH_C \
        -f $NGINX_C \
        -f $PHP_C up -d
    popd
}
# getopts
while getopts ":s:p:m:a:c:vh" opt; do
    case $opt in
        "h") usage 0;;
        "v") VERBOSE=1;;
        "s") SITE=$OPTARG;;
        "p") PHPV=$OPTARG;;
        "m") MYV=$OPTARG;;
        "a") ARCHIVE=$OPTARG;;
        "c") CONFIG=$OPTARG;;
        \?) echo "ERROR: Incorrect option -$opt"
            usage 1 ;;
    esac
done
# mandatory options
[[ -z $ARCHIVE ]] && \
    error "You need defined ARCHIVE name for site"
[[ -z $SITE ]] && \
    error "Sitename is mandatory option"

# deafult values
[[ -z $VERBOSE ]]   && VERBOSE=0
[[ -z $PHPV ]]      && PHPV=php72
[[ -z $MYV ]]       && MYV=mysql57
[[ -z $CONFIG ]]    && CONFIG=$PROGPATH/CONFIG

# process config file
source $CONFIG || error "There are no config: $CONFIG"
[[ -z $DISTR_URL ]] && \
    error "You need defined DISTR_URL option in the config $CONFIG"
[[ -z $HTML_PATH ]] && \
    error "You need defined HTML_PATH option in  the config $CONFIG"
[[ -z $PROJECT_DIR ]] && \
    error "You need defined PROJECT_DIR option in  the config $CONFIG"

[[ -n LOG_DIR ]] && LOG=$LOG_DIR/run_site.log

run_site

