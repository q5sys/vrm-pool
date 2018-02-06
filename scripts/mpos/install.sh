#!/bin/bash
set -euo


if [ "$#" -ne 3 ]; then
    echo "<database name> <datbase user> <database user password> required"
    exit
fi

dbname=$1
dbuser=$2
dbupass=$3

# Script must be run as root.
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root, exiting." 
   exit 1
fi

################################################################################
#                               # PHP5 #                                       #
################################################################################

# PHP 5(.7)
apt-get purge `dpkg -l | grep php| awk '{print $2}' |tr "\n" " "` -y
add-apt-repository ppa:ondrej/php -y
apt-get install software-properties-common -y
apt-get update
apt-get install php5.6 -y

apt-get install memcached php5.6-memcached php5.6-mysqlnd php5.6-curl php5.6-json libapache2-mod-php5.6 php5.6-mysql -y
apache2ctl -k stop; sleep 2; sudo apache2ctl -k start

################################################################################
#                               # MPOS #                                       #
################################################################################


apt-get install apache2 -y 

cd /var/www
rm -Rf MPOS
git clone git://github.com/MPOS/php-mpos.git MPOS
cd MPOS
git checkout master

# Set permissions
chown -R www-data:www-data /var/www

# Setup the database.
#mysql -u $dbuser -p $dbname --password="$dbupass" < /var/www/MPOS/sql/000_base_structure.sql

# Copy default configuration file.
cd /var/www/MPOS
cp include/config/global.inc.dist.php include/config/global.inc.php

# Set the salts.
SALT=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
SALTY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

sed -i "s|\(\$config\['SALT'\] = \).*|\1'${SALT}';|" include/config/global.inc.php
sed -i "s|\(\$config\['SALTY'\] = \).*|\1'${SALTY}';|" include/config/global.inc.php
sed -i "s|\(\$config\['algorithm'\] = \).*|\1'scryptn';|" include/config/global.inc.php
sed -i "s|\(\$config\['getbalancewithunconfirmed'\] = \).*|\1false;|" include/config/global.inc.php
#
sed -i "s|\(\$config\['db'\]\['user'\] = \).*|\1'${dbuser}';|" include/config/global.inc.php
sed -i "s|\(\$config\['db'\]\['pass'\] = \).*|\1'${dbupass}';|" include/config/global.inc.php
sed -i "s|\(\$config\['db'\]\['name'\] = \).*|\1'${dbname}';|" include/config/global.inc.php

sed -i "s|\(\$config\['wallet'\]\['host'\] = \).*|\1'localhost:33987';|" include/config/global.inc.php
sed -i "s|\(\$config\['wallet'\]\['username'\] = \).*|\1'veriumrpc';|" include/config/global.inc.php
sed -i "s|\(\$config\['wallet'\]\['password'\] = \).*|\1'walletrpcpass';|" include/config/global.inc.php

sed -i "s|\(\$config\['gettingstarted'\]\['coinname'\] = \).*|\1'Verium';|" include/config/global.inc.php
sed -i "s|\(\$config\['gettingstarted'\]\['coinurl'\] = \).*|\1'https://portal.vericoin.info/';|" include/config/global.inc.php
sed -i "s|\(\$config\['gettingstarted'\]\['stratumurl'\] = \).*|\1'moulesfrites.call-cc.be';|" include/config/global.inc.php
sed -i "s|\(\$config\['gettingstarted'\]\['stratumport'\] = \).*|\1'3333';|" include/config/global.inc.php

sed -i "s|\(\$config\['ap_threshold'\]\['min'\] = \).*|\12;|" include/config/global.inc.php
sed -i "s|\(\$config\['ap_threshold'\]\['max'\] = \).*|\120;|" include/config/global.inc.php

sed -i "s|\(\$config\['currency'\] = \).*|\1'VRM';|" include/config/global.inc.php

sed -i "s|\(\$config\['reward'\] = \).*|\13\.8;|" include/config/global.inc.php

# Configure Apache (this assumes default vanilla Apache install)
sed -i 's|DocumentRoot .*|DocumentRoot /var/www/MPOS/public|' /etc/apache2/sites-available/default-ssl.conf
sed -i 's|DocumentRoot .*|DocumentRoot /var/www/MPOS/public|' /etc/apache2/sites-available/000-default.conf
systemctl restart apache2.service



echo "################################################################################"
echo "# DO NOT FORGET TO CONFIGURE THE WALLET RPC PASSWORD IN THE CONFIG FILE AT     #"
echo "# /var/www/MPOS/include/config/global.dist.php                                 #"
echo "################################################################################"
