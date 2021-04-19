#!/bin/bash
# -- create database
# -- unpack archive
# -- cconfigure access to DB
# -- configure access to push-server

# mysql - mysql server
# MYSQL_ROOT_PASSWORD - mysql root password
# BX_MYSQL_IMAGE - version

PHPVER=php$(php --version | egrep -o "PHP\s+[0-9\.]+" | \
    awk '{print $2}' | awk -F'.' '{printf  "%d%d", $1, $2}')

WWW_DIR=/var/www/public_html/$PHPVER
DB_FILE=db.sql
SITE_FILE=files.zip
EMPTY_FILE=vm_kernel.tar.gz
USER=bitrix
GROUP=bitrix
LOG_DIR=/var/log/php-fpm
EXC_LOG=$LOG_DIR/exceptions.log

# mysql config
MY_CNF="${WWW_DIR}/my.cnf"
MY_RUNNING=0

MYSQL_VERS=(mysql57 mysql80)

basic_single_escape () {
    echo "$1" | sed 's/\(['"'"'\]\)/\\\1/g'
}

# generate random password
randpw(){
    local len="${1:-20}"
	local type="${2:-simple}"
    if [[ $type == "simple" ]]; then
        </dev/urandom tr -dc '0-9a-zA-Z' | head -c$len; echo ""
    else
        </dev/urandom tr -dc '?!@&\-_+@%\(\)\{\}\[\]=0-9a-zA-Z' | head -c$len; echo ""
    fi
}

create_my_cnf(){
    local cfg=${1:-$MY_CNF}
    local host=${2:-mysql}

    echo "++ Create $MY_CNF"

    esc_pass=$(basic_single_escape "$MYSQL_ROOT_PASSWORD")
    echo '[client]' > $cfg
    echo 'user=root' >> $cfg
    echo "password='$esc_pass'" >> $cfg
	echo "host=$host" >> $cfg

}

query_mysql(){
    local query="${1}"
    local cfg="${2:-$MY_CNF}"
    local opts="${3}"

    [[ -z $query ]] && return 1

    local tmp_f=$(mktemp /tmp/XXXXX_command)
    echo "$query" > $tmp_f
    mysql --defaults-file=$cfg $opts < $tmp_f 
    mysql_rtn=$?

    rm -f $tmp_f
    return $mysql_rtn
}

ping_mysql(){
    TRY_LIMITS=5

    while [[ $TRY_LIMITS -ge 0 && $MY_RUNNING -eq 0 ]]; do
        mysql --defaults-file=$MY_CNF \
            -N -e 'select now()\G' 1>/dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            echo "Mysql service is up and runnig"
            MY_RUNNING=1
        else
            echo "Waiting Mysql service. Sleep 10"
            sleep 10
        fi
        TRY_LIMITS=$(( $TRY_LIMITS - 1 ))
    done

    if [[ $MY_RUNNING -eq 1 ]]; then
        return 0
    else
        return 1
    fi
}

create_mysql_db(){
    dump="${1}"
    myhost="${2:-mysql}"
    is_upload="${3:-1}"

	[[ ! -f $MY_CNF ]] && create_my_cnf "$MY_CNF" "$myhost"

    [[ $MY_RUNNING -eq 0 ]] && ping_mysql

    PROJECT=
    PASSWORD=

    rand_str=$(randpw 10)

    project_str=bitrix${rand_str}
    project_password=$(randpw 15)
    esc_project_password=$(basic_single_escape $project_password)

    query_mysql "CREATE USER '$project_str'@'%' IDENTIFIED BY '$esc_project_password';"
    if [[ $? -gt 0 ]]; then
        echo "Cannot create $project_str mysql user"
        return 1
    fi
    echo "Create user $project_str"

    query_mysql "GRANT ALL PRIVILEGES ON $project_str.* TO '$project_str'@'%';"
    if [[ $? -gt 0 ]]; then
        echo  "Cannot grant access rights to $project_str on DB $project_str"
        return 2
    fi
    echo  "Grant access roghts to $project_str"

    query_mysql "CREATE DATABASE $project_str;"
    if [[ $? -gt 0  ]]; then
        echo "Cannot create database $project_str"
        return 3
    fi

    if [[ $IS_UPLOAD -gt 0 ]]; then
        mysql --defaults-file=$MY_CNF $project_str < $DB_FILE
        if [[ $? -gt 0 ]]; then
            echo "Cannot upload database data"
            return 4
        fi
        echo "Upload data to DB $project_str"
        rm -f $DB_FILE
    fi

    PROJECT="${project_str}"
    PASSWORD="${project_password}"

    return 0
}


cfg_site(){
    local dir="${1}"

    [[ -z $dir ]] && return 1

    MYSQL_VERSION=$(echo $(pwd) | \
        awk -F'/' '{print $(NF-1)}')


    # run DB configuration only if there files
    if [[ ! ( -f $DB_FILE && -f $SITE_FILE ) ]]; then
        if [[ ! -f $EMPTY_FILE ]]; then
            echo "There are no prepared files for installation.Exit."
            return 1
        else
            IS_UPLOAD=0
        fi
    else
        IS_UPLOAD=1
    fi
    if [[ -f .BITRIX_CONFIG ]]; then
        echo "There is .BITRIX_CONFIG in the directory $dir"
        return 3
    fi

    create_mysql_db "$DB_FILE" "$MYSQL_VERSION" "$IS_UPLOAD"
    [[ $? -gt 0 ]] && return 1
    echo "+++ Created DB $PROJECT"

    # unpack SITE_FILE
	# rm -f $SITE_FILE  && \
    if [[ $IS_UPLOAD -gt 0 ]]; then
        unzip -q -o $SITE_FILE && \
            chown -R ${USER}:${GROUP} .
        echo "+++ Unzip $SITE_FILE"
        rm -f $SITE_FILE
    else
        tar xzf $EMPTY_FILE && \
            chown -R ${USER}:${GROUP} .
        echo "+++ Unzip $EMPTY_FILE"
        rm -f $EMPTY_FILE
    fi

    # Update settings.php
    cat /tmp/bitrix/.settings.php | \
        sed -e "s/%DBHOST%/$MYSQL_VERSION/; \
                s/%DBNAME%/$PROJECT/; \
                s/%DBLOGIN%/$PROJECT/; \
                s/%DBPASSWORD%/$PASSWORD/; \
                s/%SECURITY_KEY%/$BX_PUSH_SECURITY_KEY/; \
                s/%BX_PUSH_PUB_HOST%/$BX_PUSH_PUB_HOST/; \
                s/%BX_PUSH_PUB_PORT%/$BX_PUSH_PUB_PORT/" > ./bitrix/.settings.php
    echo "+++ Update ./bitrix/.settings.php"
    if [[ -f ./bitrix/.settings.php.crm ]]; then
        rm -f ./bitrix/.settings.php.crm
    fi

    # Update dbconn.php
    cat /tmp/bitrix/dbconn.php | \
         sed -e "s/%DBHOST%/$MYSQL_VERSION/; \
                s/%DBNAME%/$PROJECT/; \
                s/%DBLOGIN%/$PROJECT/; \
                s/%DBPASSWORD%/$PASSWORD/; \
                s/%HOST%/$dir/;" > ./bitrix/php_interface/dbconn.php
    echo "+++ Update ./bitrix/php_interface/dbconn.php"
    if [[ -f /tmp/bitrix/dbconn.php.crm ]]; then
        rm -f /tmp/bitrix/dbconn.php.crm
    fi

    # Create .BITRIX_CONFIG
    echo "$dir:$PROJECT:$MYSQL_VERSION:$PHPVER" > .BITRIX_CONFIG

    # Create /var/www/public_html/.bx_temp/%HOST%
    [[ ! -d /var/www/public_html/.bx_temp/$dir ]] && \
        mkdir -p /var/www/public_html/.bx_temp/$dir && \
        chown -R ${USER}:${GROUP} /var/www/public_html/.bx_temp/$dir

    # Create exception log directory
    [[ ! -d $LOG_DIR ]] && \
        mkdir $LOG_DIR -p && \
        touch $EXC_LOG  && \
        chown -R ${USER}:${GROUP} $LOG_DIR
    
    return 0
}

cfg_sites(){

    # BEGIN phpVERSION dir
    echo "pushd $WWW_DIR"
    pushd $WWW_DIR 1>/dev/null 2>&1 || exit
    echo "Processing $WWW_DIR"

    mysql_dirs=$(find -maxdepth 1 -name "mysql*" -type d)
    IFS_BAk=$IFS
    IFS=$'\n'
    for fm in $mysql_dirs; do
        fm=$(basename $fm)
        echo "= MySQL: $fm"

        if_supported_ver=$(printf "%s\n" "${MYSQL_VERS[@]}" | \
            grep -cP "^$fm$") 
        if [[ $if_supported_ver -eq 0 ]]; then
            echo "= Not supported. Skip."
            continue
        fi

        # BEGIN mysqlVERSION dir
        echo ">> pushd $fm"
        pushd $fm >/dev/null 2>&1|| exit
        echo "= Processing $fm"
        site_dirs=$(find -maxdepth 1 -type d ! -name ".")

        if [[ -z $site_dirs ]]; then
            echo "= There are no site's directories. Skip."
            echo echo "<<<<< exit ${f}"
            popd >/dev/null 2>&1
            continue
        fi

        for f in $site_dirs; do
            f=$(basename $f)
            echo "== Site Directory: $f"

            # BEGIN site
            echo ">>>>> ${f}"
            pushd ${f} >/dev/null 2>&1 || exit
            
            cfg_site "${f}"
            echo "== return $?"
            
            # END site
            echo "<<<<< exit ${f}"
            popd >/dev/null 2>&1
        done

        # END mysqlVERSION dir
        echo "<< exit ${fm}"
        popd >/dev/null 2>&1
    done
    IFS=$IFS_BAK

    # END phpVERSION dir
    echo "exit $WWW_DIR"
    popd >/dev/null 2>&1
}


[[ $BX_HOST_AUTOCREATE == 1 ]] && cfg_sites
 
[[ $DEBUG == true ]] && set -x

# allow arguments to be passed to nginx
if [[ ${1:0:1} = '-' ]]; then
    EXTRA_ARGS="$@"
    set --
elif [[ ${1} == php-fpm || ${1} == $(which php-fpm) ]]; then
    EXTRA_ARGS="${@:2}"
    set --
fi

if [[ -z ${1} ]]; then
    echo "Starting php-fpm..."
    exec $(which php-fpm) "--nodaemonize" ${EXTRA_ARGS}
else
    exec "$@"
fi
