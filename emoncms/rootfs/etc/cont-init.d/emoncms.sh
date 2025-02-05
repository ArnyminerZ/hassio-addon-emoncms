#!/usr/bin/with-contenv bashio
# ==============================================================================
# Home Assistant Community Add-on: EmonCms
# Configures EmonCms
# ==============================================================================

declare mysql_host
declare mysql_database
declare mysql_username
declare mysql_password
declare mysql_port

declare remote_redis_host
declare remote_redis_port
declare remote_redis_auth
declare remote_redis_dbnum
declare remote_redis_prefix

if bashio::config.has_value "remote_mysql_host"; then
    if ! bashio::config.has_value 'remote_mysql_database'; then
        bashio::exit.nok \
            "Remote database has been specified but no database is configured"
    fi

    if ! bashio::config.has_value 'remote_mysql_username'; then
        bashio::exit.nok \
            "Remote database has been specified but no username is configured"
    fi

    if ! bashio::config.has_value 'remote_mysql_password'; then
        bashio::log.fatal \
            "Remote database has been specified but no password is configured"
    fi

    if ! bashio::config.exists 'remote_mysql_port'; then
        bashio::exit.nok \
            "Remote database has been specified but no port is configured"
    fi
else
    if ! bashio::services.available 'mysql'; then
        bashio::log.fatal \
            "Local database access should be provided by the MariaDB addon"
        bashio::exit.nok \
            "Please ensure it is installed and started"
    fi

    mysql_host=$(bashio::services "mysql" "host")
    mysql_password=$(bashio::services "mysql" "password")
    mysql_port=$(bashio::services "mysql" "port")
    mysql_username=$(bashio::services "mysql" "username")
    mysql_database=emoncms

    bashio::log.warning "Emoncms is using the Maria DB addon"
    bashio::log.warning "Please ensure this is included in your backups"
    bashio::log.warning "Uninstalling the MariaDB addon will remove any data"

    bashio::log.info "Creating database for Emoncms if required"

    mysql \
        -u "${mysql_username}" -p"${mysql_password}" \
        -h "${mysql_host}" -P "${mysql_port}" \
        -e "CREATE DATABASE IF NOT EXISTS \`${mysql_database}\` ;"
fi

if [ "$(bashio::config \"redis\")" == 'true' ]; then
    if bashio::config.has_value "remote_redis_host"; then
        # All options must have been set
        if ! bashio::config.has_value 'remote_redis_port'; then
            bashio::exit.nok \
                "Remote redis host has been specified but no port is configured"
        fi

        if ! bashio::config.has_value 'remote_redis_prefix'; then
            bashio::exit.nok \
                "Remote redis host has been specified but no prefix is configured"
        fi
    fi
else
    bashio::log.warning "Redis not enabled. This will stress more your SD card."
fi

cd /var/www/emoncms

bashio::log.info "Configuring settings.php"

cp example.settings.php settings.php

# Setup Database params
sed -i "s/\"server\"   => \"localhost\"/\"server\"   => getenv('MYSQL_HOST')/g" settings.php
sed -i "s/\"database\" => \"emoncms\"/\"database\" => getenv('MYSQL_NAME')/g" settings.php
sed -i "s/\"_DB_USER_\"/getenv('MYSQL_USERNAME')/g" settings.php
sed -i "s/\"_DB_PASSWORD_\"/getenv('MYSQL_PASSWORD')/g" settings.php
sed -i "s/\"port\"     => 3306/\"port\"     => getenv('MYSQL_PORT')/g" settings.php

# Setup data directories
sed -i "s/\/var\/opt\/emoncms\/phpfina\//\/data\/emoncms\/phpfina\//g" settings.php
sed -i "s/\/var\/opt\/emoncms\/phptimeseries\//\/data\/emoncms\/phptimeseries\//g" settings.php

# Enable Redis, and set env options
python3 -c "# Read in the file
with open('default-settings.php', 'r') as file :
    filedata = file.read()

# Replace the target string
filedata = filedata.replace(
    '\"redis\"=>array(\n    \'enabled\' => false,\n    \'host\'    => \'localhost\',\n    \'port\'    => 6379,\n    \'auth\'    => \'\',\n    \'dbnum\'   => \'\',\n    \'prefix\'  => \'emoncms\'',
    '\"redis\"=>array(\n    \'enabled\' => getenv(\'REDIS_ENABLED\'),\n    \'host\'    => getenv(\'REDIS_HOST\'),\n    \'port\'    => getenv(\'REDIS_PORT\'),\n    \'auth\'    => getenv(\'REDIS_AUTH\'),\n    \'dbnum\'   => getenv(\'REDIS_DBNUM\'),\n    \'prefix\'  => getenv(\'REDIS_PREFIX\')'
)

# Write the file out again
with open('settings.php', 'w') as file:
    file.write(filedata)"

# Configure logging
bashio::log.info "Setting up logging"
mkdir -p /var/log/emoncms
touch /var/log/emoncms/emoncms.log
chmod 666 /var/log/emoncms/emoncms.log

# Configure persistant storage

bashio::log.info "Setting up persistant storage"

# Ensure persistant storage exists
if ! bashio::fs.directory_exists "/data/emoncms"; then
    bashio::log.debug 'Data directory not initialized, doing that now...'

    # Create directories
    mkdir -p /data/emoncms/phpfina
    mkdir -p /data/emoncms/phptimeseries

    # Ensure file permissions
    chown -R nginx:nginx /data/emoncms
    find /data/emoncms -not -perm 0644 -type f -exec chmod 0644 {} \;
    find /data/emoncms -not -perm 0755 -type d -exec chmod 0755 {} \;
fi

# Run migrations

bashio::log.info "Running migrations if needed"

export MYSQL_HOST
export MYSQL_NAME
export MYSQL_USERNAME
export MYSQL_PASSWORD
export MYSQL_PORT

if bashio::config.has_value 'remote_mysql_host'; then
    MYSQL_HOST=$(bashio::config "remote_mysql_host")
    MYSQL_NAME=$(bashio::config "remote_mysql_database")
    MYSQL_USERNAME=$(bashio::config "remote_mysql_username")
    MYSQL_PASSWORD=$(bashio::config "remote_mysql_password")
    MYSQL_PORT=$(bashio::config "remote_mysql_port")
else
    MYSQL_HOST=$(bashio::services "mysql" "host")
    MYSQL_NAME=emoncms
    MYSQL_USERNAME=$(bashio::services "mysql" "username")
    MYSQL_PASSWORD=$(bashio::services "mysql" "password")
    MYSQL_PORT=$(bashio::services "mysql" "port")
fi

export REDIS_ENABLED
export REDIS_HOST
export REDIS_PORT
export REDIS_AUTH
export REDIS_DBNUM
export REDIS_PREFIX

REDIS_ENABLED=$(bashio::config "redis")
if bashio::config.has_value 'remote_redis_host'; then
    REDIS_HOST=$(bashio::config "remote_redis_host")
    REDIS_PORT=$(bashio::config "remote_redis_port")
    REDIS_AUTH=$(bashio::config "remote_redis_auth")
    REDIS_DBNUM=$(bashio::config "remote_redis_dbnum")
    REDIS_PREFIX=$(bashio::config "remote_redis_prefix")
else
    REDIS_HOST=localhost
    REDIS_PORT=6379
    REDIS_AUTH=""
    REDIS_DBNUM=""
    REDIS_PREFIX="emoncms"
fi

/usr/bin/php7 scripts/emoncms-cli admin:dbupdate

# Start the service runner
bashio::log.info "Starting service runner..."
python3 /var/www/emoncms/Modules/backup/service-runner.py
