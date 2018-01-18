#!/bin/bash

systemctl stop mysql.service
killall -9 mysql
killall -9 mysqld
apt-get remove --purge 'mysql*' -y
apt-get autoremove -y
apt-get autoclean -y
deluser mysql
rm -Rf /var/lib/mysql
rm -Rf /var/log/mysql
rm -Rf /etc/mysql
rm -Rf /var/lib/mysql-files/

killall -u walletuser
killall -u startumuser
deluser -f walletuser
deluser -f stratumuser 
rm -Rf /home/stratumuser 
rm -Rf /home/walletuser

rm -Rf /var/www/MPOS