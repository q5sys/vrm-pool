#!/bin/bash
set -euo

# Script must be run as root.
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root, exiting." 
   exit 1
fi

#############
# Passwords #
#############

ROOTPW=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 128 ; echo '')
echo "mysql root password: ${ROOTPW}"
echo "${ROOTPW}" > /root/mysql_password.txt

########################
# Install MySql Server #
########################

export DEBIAN_FRONTEND='noninteractive'
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $ROOTPW"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $ROOTPW"
apt install mysql-server -y

########################
# Extra configuration  #
########################

cp /etc/mysql/my.cnf /etc/mysql/my.cnf.BAK

{
echo " "
echo "[mysqld]"
echo '!sql_mode='STRICT_TRANS_TABLES\,NO_ZERO_IN_DATE\,NO_ZERO_DATE\,ERROR_FOR_DIVISION_BY_ZERO\,NO_AUTO_CREATE_USER\,NO_ENGINE_SUBSTITUTION';'
} >> /etc/mysql/my.cnf

/etc/init.d/mysql restart


mysql -u root --password="$ROOTPW" << QUERY
    DELETE FROM mysql.user WHERE User='';
    DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
    DROP DATABASE IF EXISTS test;
    DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
    FLUSH PRIVILEGES;
QUERY
