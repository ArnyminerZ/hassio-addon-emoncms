#!/bin/bash
backup_module_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $backup_module_dir
openenergymonitor_dir=/opt/openenergymonitor

user=root
emoncms_www=/var/www/emoncms
emoncms_datadir=/var/www/emoncms

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
    echo "- Moving config.cfg to the backup module"
    mkdir -p /opt/emoncms/backup
    mkdir -p /opt/emoncms/modules/backup
    cp config.cfg /opt/emoncms/modules/backup/config.cfg
    cp config.cfg /opt/emoncms/backup/config.cfg
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

php_ini=/etc/php7/php.ini

echo "- configuring PHP ($php_ini)..."
python3 -c "import configparser
config = configparser.ConfigParser()
config.read('$php_ini')
config.set('PHP', 'post_max_size', '3G')
config.set('PHP', 'upload_max_filesize', '3G')
config.set('PHP', 'upload_tmp_dir', '$upload_location')
with open('$php_ini', 'w') as configfile:
    config.write(configfile)"

# Create uploads folder
if [ ! -d $backup_location ]; then
    echo "- creating $backup_location directory"
    mkdir $backup_location
    chown $user:$user $backup_location -R
fi

if [ ! -d $backup_location/uploads ]; then
    echo "- creating $backup_location/uploads directory"
    mkdir $backup_location/uploads
    chown $user:$user $backup_location/uploads -R
fi
