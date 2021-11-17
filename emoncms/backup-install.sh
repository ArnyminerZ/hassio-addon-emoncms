#!/bin/bash
backup_module_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $backup_module_dir
openenergymonitor_dir=/opt/openenergymonitor

user=root
emoncms_www=/var/www/emoncms
emoncms_datadir=/var/opt/emoncms

# Creating backup module config.cfg file
if [ ! -f config.cfg ]; then
    echo "- Copying default.config.cfg to config.cfg"
    cp default.config.cfg config.cfg
    echo "- Setting config.cfg settings"
    sed -i "s~USER~$user~" config.cfg
    sed -i "s~BACKUP_SCRIPT_LOCATION~$backup_module_dir~" config.cfg
    sed -i "s~EMONCMS_LOCATION~$emoncms_www~" config.cfg
    sed -i "s~BACKUP_LOCATION~$emoncms_datadir/backup~" config.cfg
    sed -i "s~DATABASE_PATH~$emoncms_datadir~" config.cfg
    sed -i "s~BACKUP_SOURCE_PATH~$emoncms_datadir/backup/uploads~" config.cfg
else
    echo "- config.cfg already exists, left unmodified"
fi
source config.cfg

# Load backup module configuration file
upload_location=$backup_location/uploads

# Symlink emoncms UI (if not done so already)
if [ ! -L $emoncms_www/Modules/backup ]; then
    echo "- symlinking backup module"
    ln -s $backup_module_dir/backup-module $emoncms_www/Modules/backup
fi

# php_ini=/etc/php5/apache2/php.ini
PHP_VER=$(php -v | head -n 1 | cut -d " " -f 2 | cut -f1-2 -d"." )
php_ini=/etc/php/$PHP_VER/apache2/php.ini
# echo "- PHP Version: $PHP_VER"

echo "- creating /etc/php/$PHP_VER/mods-available/emoncmsbackup.ini"
cat << EOF |
post_max_size = 3G
upload_max_filesize = 3G
upload_tmp_dir = ${upload_location}
EOF
tee /etc/php/$PHP_VER/mods-available/emoncmsbackup.ini

echo "- phpenmod emoncmsbackup"
phpenmod emoncmsbackup

# Create uploads folder
if [ ! -d $backup_location ]; then
    echo "- creating $backup_location directory"
    mkdir $backup_location
    chown $user:$user $backup_location -R
fi

if [ ! -d $backup_location/uploads ]; then
    echo "- creating $backup_location/uploads directory"
    mkdir $backup_location/uploads
    chown www-data:$user $backup_location/uploads -R
fi

echo "- restarting nginx"
nginx -s reload -c /conf/nginx/nginx.conf
