#!/bin/bash
#set -x

PROGNAME=$(basename $0)
PROGPATH=$(dirname $0)

source $PROGPATH/common.sh || exit 255


usage(){
    rtn=${1:-0}

    echo "Usage: $PROGNAME -s site_name"
    echo "Options:"
    echo "-h  - show this help message"
    echo "-v  - enable verbose mode"
    echo "-s  - site name"
    echo "-c  - config file (default: $PROGPATH/CONFIG)"

    exit $rtn
}

redis_volume(){
    data_volume=$(docker inspect bx-redis 2>&1  | \
        grep Source -B1 | awk -F'"' '/Name/{print $4}')

    if [[ -n $data_volume ]]; then
        echo -n $data_volume
    else
        echo -n ""
    fi
    return 0

}

down_containers(){
    DOWN_LIST=

    REDIS_VOLUME=$(redis_volume)
    echo "REDIS_VOLUME=$REDIS_VOLUME"

    pushd $PROJECT_DIR
    # php list
    for ver in ${PHP_VERSIONS[@]}; do
        status_docker $ver

        if [[ $? -gt 0 ]]; then
            log "There is running PHP container: $ver"
            DOWN_LIST="${DOWN_LIST} -f docker-compose-${ver}.yml"
        fi
    done

    # mysql list
    for ver in ${MYSQL_VERSIONS[@]}; do
        status_docker $ver

        if [[ $? -gt 0 ]]; then
            log "There is running MYSQL container: $ver"
            DOWN_LIST="${DOWN_LIST} -f docker-compose-${ver}.yml"
        fi
    done

    
    status_docker memcached
    [[ $? -gt 0 ]] && \
        DOWN_LIST="$DOWN_LIST -f docker-compose.yml"

    status_docker nginx
    [[ $? -gt 0 ]] && \
        DOWN_LIST="$DOWN_LIST -f docker-compose-nginx.yml"

    status_docker push
    [[ $? -gt 0 ]] && DOWN_LIST="$DOWN_LIST -f docker-compose-push.yml"

    if [[ -n $DOWN_LIST ]]; then
        docker-compose -f docker-compose-net.yml $DOWN_LIST down
        log "Down all containers"
    fi
    popd

    docker_volume_rm "$REDIS_VOLUME"

}
clean_folders(){
    pushd $HTML_PATH 

    # php list
    for ver in ${PHP_VERSIONS[@]}; do
        rm -fr "${ver}"

        for myver in ${MYSQL_VERSIONS[@]}; do
            mkdir -p "${ver}/${myver}"
            log "Recreate ${ver}/${myver}"
        done
    done
    popd

    pushd $LOG_DIR
    rm -rf php7{1,2,3,4} php80 mysql{57,80} nginx push
    mkdir -p php7{1,2,3,4} php80 mysql{57,80} nginx push/{sub,pub}
    popd

    pushd $MYSQL_PATH
    rm -rf mysql57 mysql80
    mkdir mysql57 mysql80
    popd


}
# getopts
while getopts ":s:c:vh" opt; do
    case $opt in
        "h") usage 0;;
        "v") VERBOSE=1;;
        "s") SITE=$OPTARG;;
        "c") CONFIG=$OPTARG;;
        \?) echo "ERROR: Incorrect option -$opt"
            usage 1 ;;
    esac
done
# deafult values
[[ -z $VERBOSE ]]   && VERBOSE=0
[[ -z $CONFIG ]]    && CONFIG=$PROGPATH/CONFIG

# process config file
source $CONFIG || error "There are no config: $CONFIG"
[[ -z $PROJECT_DIR ]] && \
    error "You need defined PROJECT_DIR option in the config $CONFIG"

[[ -z $HTML_PATH ]] && \
    error "You need defined HTML_PATH option in the config $CONFIG"

[[ -n LOG_DIR ]] && LOG=$LOG_DIR/clear_all.log

down_containers

docker_volumes_rm

clean_folders

