#!/bin/bash
#set -x

FULLPATH=$(realpath $0)

PROGNAME=$(basename $FULLPATH)
PROGPATH=$(dirname $FULLPATH)

source $PROGPATH/common.sh || exit 255


usage(){
    rtn=${1:-0}

    echo "Usage: $PROGNAME [-vhblC] [-c /path/to/config]"
    echo "Options:"
    echo "-h  - show this help message"
    echo "-v  - enable verbose mode"
    echo "-c  - config file (default: $PROGPATH/CONFIG)"
    echo "-b  - build docker images (default: disable)"
    echo "-l  - local installation; created html folders"
    echo "-C  - disable configuration creation"

    exit $rtn
}

create_configs(){
    PROJECT_USER_DEFAULT=$(stat -c "%U" $(tty))
    read -p \
        "The runtime user ($PROJECT_USER_DEFAULT): " \
        PROJECT_USER
    if [[ -z $PROJECT_USER ]]; then
        PROJECT_USER=$PROJECT_USER_DEFAULT
    fi


    # список подготовленных дистрибутивов
    DISTR_URL_DEFAULT=$(echo $HOME)/distrs
    read -p \
        "URL or PATH to the prepared distribution directory ($DISTR_URL_DEFAULT): " \
        DISTR_URL
    if [[ -z $DISTR_URL ]]; then
        log "Set distrs url to default."
        DISTR_URL=$DISTR_URL_DEFAULT
        [[ ! -d $DISTR_URL ]] && mkdir -p $DISTR_URL
        chown -R $PROJECT_USER $DISTR_URL
    fi

    # каталог сайтов
    HTML_PATH_DEFAULT=$(echo $HOME)/sites
    read -p \
        "The path on the Docker server where the site directories will be located ($HTML_PATH_DEFAULT): " \
        HTML_PATH
 
    if [[ -z $HTML_PATH ]]; then
        log "Set sites path to default."
        HTML_PATH=$HTML_PATH_DEFAULT
        [[ ! -d $HTML_PATH ]] && mkdir -p $HTML_PATH
        chown -R $PROJECT_USER $HTML_PATH
    fi

    # каталог модулей
    MODULES_PATH_DEFAULT=$(echo $HOME)/modules
    read -p \
        "The path on the Docker server where the modules will be located ($MODULES_PATH_DEFAULT): " \
        MODULES_PATH
    if [[ -z $MODULES_PATH ]]; then
        log "Set modules path to default"
        MODULES_PATH=$MODULES_PATH_DEFAULT
        [[ ! -d $MODULES_PATH ]] && \
            mkdir -p $MODULES_PATH && \
            chown -R $PROJECT_USER $MODULES_PATH
    fi

    # mysql57
    #read -p \
    #    "The path to mysql path: " \
    #    MYSQL_PATH
    #if [[ -z $MYSQL_PATH ]]; then
    #    log "MySQL path set to default value: $PROJECT_DIR/var/mysql"
    #    MYSQL_PATH=$PROJECT_DIR/var/mysql
    #fi
    #[[ ! -d $MYSQL_PATH ]] && mkdir -p $MYSQL_PATH
    #[[ ! -d $MYSQL_PATH/mysql57 ]] && mkdir -p $MYSQL_PATH/mysql57
    #[[ ! -d $MYSQL_PATH/mysql80 ]] && mkdir -p $MYSQL_PATH/mysql80
 

    # каталог со всем проектом  bx-env
    PROJECT_DIR_DEFAULT=$(dirname $PROGPATH)
    read -p \
        "The directory where the bx-env project is located ($PROJECT_DIR_DEFAULT): " \
        PROJECT_DIR
    if [[ -z $PROJECT_DIR ]]; then
        PROJECT_DIR=$PROJECT_DIR_DEFAULT
    fi

    # каталог логов
    LOG_DIR_DEFAULT=$(echo $HOME)/logs
    read -p \
        "Log directory ($LOG_DIR_DEFAULT): " \
        LOG_DIR
    if [[ -z $LOG_DIR ]]; then
        log "Set log path to default."
        LOG_DIR=$LOG_DIR_DEFAULT
    fi

    [[ ! -d $LOG_DIR ]] && mkdir -p $LOG_DIR
    pushd $LOG_DIR 1>/dev/null 2>&1
    mkdir php7{1,2,3,4} php80 mysql{57,80} nginx push 2>/dev/null
    popd 1>/dev/null 2>&1
    chown $PROJECT_USER $LOG_DIR -R

    read -p \
        "Enter default domain name for sites(example ksh.bx): " \
        DEFAULT_DOMAIN
    [[ -z $DEFAULT_DOMAIN ]] && \
        error "Default domain name cannot be emty"

    read -p \
        "Enter default sitename: (default $DEFAULT_DOMAIN): " \
        DEFAULT_SITENAME
    [[ -z $DEFAULT_SITENAME ]] && \
        DEFAULT_SITENAME=$DEFAULT_DOMAIN

    PUSH_KEY=$(create_random_key)
    MYSQL_PASSWORD=$(create_random_password)

    log "DISTR_URL=\"$DISTR_URL\""
    log "HTML_PATH=\"$HTML_PATH\""
    log "PROJECT_DIR=\"$PROJECT_DIR\""
    log "MYSQL_PATH=\"$MYSQL_PATH\""
    log "DEFAULT_DOMAIN=\"$DEFAULT_DOMAIN\""
    log "DEFAULT_SITENAME=\"$DEFAULT_SITENAME\""
    log "PUSH_KEY=\"$PUSH_KEY\""
    log "USER=\"$PROJECT_USER\""

    read -p "Please confirm to save the selected options (N|y): " user_answer

    if [[ $(echo "$user_answer" | grep -cwi "y") -gt 0 ]]; then
        # сохраняем конфиг для скриптов
        echo -e "DISTR_URL=\"$DISTR_URL\"\n" > $CONFIG
        echo -e "HTML_PATH=\"$HTML_PATH\"\n" >> $CONFIG
        echo -e "PROJECT_DIR=\"$PROJECT_DIR\"\n" >> $CONFIG
        echo -e "LOG_DIR=\"$LOG_DIR\"" >> $CONFIG
        echo -e "MYSQL_PATH=\"$MYSQL_PATH\"" >> $CONFIG
        log "Update config file $CONFIG"

        # обновляем конфиг docker-composer
        ENV_CONF=$PROJECT_DIR/.env
        ENV_CONF_DEFAULT=$PROJECT_DIR/.env.default
        cat "$ENV_CONF_DEFAULT" | \
        sed -e "s:%BX_PUBLIC_HTML_PATH%:$HTML_PATH:; \
                s:%BX_LOGS_PATH%:$LOG_DIR:; \
                s:%BX_MYSQL_ROOT_PASSWORD%:$MYSQL_PASSWORD:; \
                s:%BX_MYSQL57_PATH%:$MYSQL_PATH/mysql57:; \
                s:%BX_MYSQL80_PATH%:$MYSQL_PATH/mysql80:; \
                s:%BX_PUSH_SUB_HOST%:sub.$DEFAULT_DOMAIN:; \
                s:%BX_PUSH_PUB_HOST%:pub.$DEFAULT_DOMAIN:; \
                s:%BX_PUSH_SECURITY_KEY%:$PUSH_KEY:; \
                s:%BX_DEFAULT_HOST%:$DEFAULT_SITENAME:; \
                s:%BX_DEFAULT_LOCAL_DOMAIN%:$DEFAULT_DOMAIN:" > $ENV_CONF
        [[ -n $MODULES_PATH ]] && \
            echo "BX_MODULES_PATH=$MODULES_PATH" >> $ENV_CONF


        log "Update config file $ENV_CONF"
    fi

}

upload_config(){
    [[ ! -f $CONFIG ]] && \
        error "There is no $CONFIG file; you need to create one"
    source $CONFIG
}

create_folders(){
    [[ -z $HTML_PATH ]] && \
        error "You need define HTML_PATH=; by config or arg"

    [[ ! -d $HTML_PATH ]] && mkdir -p $HTML_PATH
    pushd $HTML_PATH 

    # php list
    for ver in ${PHP_VERSIONS[@]}; do

        for myver in ${MYSQL_VERSIONS[@]}; do
            if [[ ! -d ${ver}/${myver} ]]; then
                mkdir -p "${ver}/${myver}"
                chown -R $PROJECT_USER "${ver}" 
                log "Create ${ver}/${myver}"
            fi
        done
    done
    popd
}

build_images(){
    [[ -z $PROJECT_DIR ]] && \
        error "You need define PROJECT_DIR=; by config or arg"

    pushd $PROJECT_DIR

    for dir in $(find ./ -maxdepth 1 -type d ! -name "." ! -name ".git"); do
        if [[ -f $dir/Dockerfile ]]; then
            name=$(basename $dir)

            pushd $dir
            docker build . --tag $name
            popd
        fi
    done
    popd
}

# getopts
while getopts ":c:blvhC" opt; do
    case $opt in
        "h") usage 0;;
        "v") VERBOSE=1;;
        "c") CONFIG=$OPTARG;;
        "l") IS_LOCAL=1;;
		"b") IS_BUILD=1;;
        "C") IS_CONFIG=0 ;;
        \?) echo "ERROR: Incorrect option -$opt"
            usage 1 ;;
    esac
done

# deafult values
[[ -z $VERBOSE ]]   && VERBOSE=0
[[ -z $CONFIG ]]    && CONFIG=$PROGPATH/CONFIG
[[ -z $IS_LOCAL ]]  && IS_LOCAL=0
[[ -z $IS_BUILD ]] && IS_BUILD=0
[[ -z $IS_CONFIG ]] && IS_CONFIG=1

[[ -n $LOG_DIR ]] && LOG=$LOG_DIR/configure.log

log "Start configuration of Docker Env"

if [[ $IS_CONFIG -gt 0 ]]; then
    create_configs
else
    upload_config
fi

# create folders
if [[ $IS_LOCAL -gt 0 ]]; then
    create_folders
fi

# build images
if [[ $IS_BUILD -gt 0 ]]; then
    build_images
fi


