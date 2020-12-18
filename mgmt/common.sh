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

PHP_VERSIONS=('php71' 'php72' 'php73' 'php74')
MYSQL_VERSIONS=('mysql57' 'mysql80')

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

status_docker(){
    service="${1}"
    is_up="${2:-1}"
    TMP_FILE=$(mktemp /dev/shm/XXXXX_docker)

    if [[ $is_up -gt 0 ]]; then
        docker ps > $TMP_FILE 2>&1
        docker_rtn=$?
    else
        docker ps -a > $TMP_FILE 2>&1
        docker_rtn=$?
    fi

    if [[ $docker_rtn -gt 0 ]]; then
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

create_random_key() {
    randLength=32
    rndStr=</dev/urandom tr -dc A-F0-9 | head -c $randLength
    echo $rndStr
}

create_random_password() {
    randLength=16
    rndStr=</dev/urandom tr -dc A-Za-z0-9 | head -c $randLength
    echo $rndStr
}
