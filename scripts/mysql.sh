#!/bin/bash

PASS1=$(openssl rand -base64 32)
PASS2=$(openssl rand -base64 32)
PASS3=$(openssl rand -base64 32)
PASS4=$(openssl rand -base64 32)
PASS5=$(openssl rand -base64 32)

echo "mysql root  : ${PASS1}" > passwords.txt
echo "mysql mpos  : ${PASS2}" >> passwords.txt
echo "wallet user : ${PASS3}" >> passwords.txt
echo "wallet rpc  : ${PASS4}" >> passwords.txt
echo "stratum user: ${PASS5}" >> passwords.txt

# MySQL users.
dbpass=$PASS1
dbname="mposmoulesfrites"
dbuser="mposmoulesfritesuser"
dbupass=$PASS2

# Unix user for the wallet process.
walletusername="walletuser"
walletuserpassword=$PASS3

walletrpcuser="veriumrpc"
walletrpcpass=$PASS4
walletrpcport=33987

# Unix user for the stratum process.
stratumuser="stratumuser"
stratumuserpassword=$PASS5

domain="moulesfrites.call-cc.be"

ROOTPW=$dbpass
export DEBIAN_FRONTEND='noninteractive'
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $ROOTPW"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $ROOTPW"
apt install mysql-server -y

cp /etc/mysql/my.cnf /etc/mysql/my.cnf.BAK
echo " " >> /etc/mysql/my.cnf
echo "[mysqld]" >> /etc/mysql/my.cnf
echo '!sql_mode='STRICT_TRANS_TABLES\,NO_ZERO_IN_DATE\,NO_ZERO_DATE\,ERROR_FOR_DIVISION_BY_ZERO\,NO_AUTO_CREATE_USER\,NO_ENGINE_SUBSTITUTION';' >> /etc/mysql/my.cnf
/etc/init.d/mysql restart

echo "Root password: ${ROOTPW}"
# This part is interactive.
mysql_secure_installation

mysql -u root --password="$dbpass" << QUERY
CREATE USER '$dbuser'@'localhost' IDENTIFIED BY '$dbupass';
GRANT ALL PRIVILEGES ON $dbname.* To '$dbuser'@'localhost' IDENTIFIED BY '$dbupass';
FLUSH PRIVILEGES;
SHOW GRANTS FOR '$dbuser'@'localhost';

QUERY
