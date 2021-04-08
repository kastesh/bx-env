#!/bin/bash
#set -x

PROGNAME=$(basename $0)
PROGPATH=$(dirname $0)

source $PROGPATH/common.sh || exit 255

IS_EMPTY=0

usage(){
    rtn=${1:-0}

    echo "Usage: $PROGNAME -s site_name -p php_version -m mysql_version [-a archive_name]|[-e]"
    echo "Options:"
    echo "-h  - show this help message"
    echo "-v  - enable verbose mode"
    echo "-s  - site name"
    echo "-p  - php version (default: php72)"
    echo "-m  - mysql version (default: mysql57)"
    echo "-a  - archive name (example: 20.200.300/b24)"
    echo "-e  - create empty site with bitrixsetup.php"
    echo "-c  - config file (default: $PROGPATH/CONFIG)"

    exit $rtn
}

copy_archive_files(){
    IS_HTTP=$(echo "$DISTR_URL" | grep -c '^http')

    # copy files
    DB="$DISTR_URL/${ARCHIVE}.sql"
    ARCH="$DISTR_URL/${ARCHIVE}.zip"

    if [[ ! -d $SITE_DIR ]]; then
        mkdir -p $SITE_DIR
        pushd $SITE_DIR >/dev/null 2>&1
        if [[ $IS_HTTP -gt 0 ]]; then
            log "Download DB=${ARCHIVE}.sql"
            curl -s "$DB" --output db.sql || \
                return 1
            log "Download Files=${ARCHIVE}.zip"
            curl -s "$ARCH" --output files.zip || \
                return 2
        else 

            log "Copy DB=${ARCHIVE}.sql"
            cp -f $DB db.sql
            log "Copy Files=${ARCHIVE}.zip"
            cp -f $ARCH files.zip
        fi

        log "Upload files to $SITE_DIR"
        popd >/dev/null 2>&1
    fi


}

copy_bitrixsetup(){
    EMPTY_ARCH="https://repos.1c-bitrix.ru/vm/vm_kernel.tar.gz"

    if [[ ! -d $SITE_DIR ]]; then
        mkdir -p $SITE_DIR
        pushd $SITE_DIR >/dev/null 2>&1
        log "Download Files=$EMPTY_ARCH"
        curl -s "$EMPTY_ARCH" \
            --output vm_kernel.tar.gz || return 1

        log "Upload files to $SITE_DIR"
        popd >/dev/null 2>&1
    fi
}

run_site(){
    SITE_DIR="$HTML_PATH/$PHPV/$MYV/$SITE"

    if [[ -f $SITE_DIR/.BITRIX_CONFIG ]]; then
        log "The site istallation already exists in $SITE_DIR"
        return 1
    fi

    if [[ $IS_EMPTY == 0 ]]; then
        copy_archive_files || return 1
    else
        copy_bitrixsetup || return 1
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
    echo docker-compose -f $NET_C \
        -f $BASE_C \
        -f $MYSQL_C \
        -f $PUSH_C \
        -f $NGINX_C \
        -f $PHP_C up -d
    docker-compose -f $NET_C \
        -f $BASE_C \
        -f $MYSQL_C \
        -f $PUSH_C \
        -f $NGINX_C \
        -f $PHP_C up -d

    popd
}
# getopts
while getopts ":s:p:m:a:c:vhe" opt; do
    case $opt in
        "h") usage 0;;
        "v") VERBOSE=1;;
        "s") SITE=$OPTARG;;
        "p") PHPV=$OPTARG;;
        "m") MYV=$OPTARG;;
        "a") ARCHIVE=$OPTARG;;
        "c") CONFIG=$OPTARG;;
        "e") IS_EMPTY=1;;
        \?) echo "ERROR: Incorrect option -$opt"
            usage 1 ;;
    esac
done
# mandatory options
[[ -z $ARCHIVE && ( $IS_EMPTY -eq 0 ) ]] && \
    error "You must specify the path to the ARCHIVE to create or define the creation of an empty site."
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

