#!/bin/bash

################################################################################
#                               # Vars #                                       #
################################################################################

PASS1=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 128 ; echo '')
PASS2=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 128 ; echo '')
PASS3=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 128 ; echo '')
PASS4=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 128 ; echo '')
PASS5=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 128 ; echo '')


read -p "Will overwrite old passwords. Are you sure? " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
    echo "mysql root  : ${PASS1}" > passwords.txt
    echo "mysql mpos  : ${PASS2}" >> passwords.txt
    echo "wallet user : ${PASS3}" >> passwords.txt
    echo "wallet rpc  : ${PASS4}" >> passwords.txt
    echo "stratum user: ${PASS5}" >> passwords.txt
else
    exit 
fi

# MySQL users.
dbpass=${PASS1}
dbname="mposmoulesfrites"
dbuser="mposmoulesfritesuser"
dbupass=$PASS2

# Unix user for the wallet process.
walletusername="walletuser"
walletuserpassword=$PASS3

walletrpcuser="veriumrpc"
walletrpcpass=$PASS4
walletrpcport=33987
walletrpcallowip=""

# Unix user for the stratum process.
stratumuser="stratumuser"
stratumuserpassword=$PASS5

domain="moulesfrites.call-cc.be"

################################################################################
#                               # Debugging #                                  #
################################################################################

# If we have an argument, check which one it is.
if [ "$#" == 1 ] ; then
  if [ $1 == "dropdb" ] ; then
       	echo "Dropping tables.."
        # Drop the database, and create it again.
        mysql -u root --password="$dbpass" << QUERY
        DROP DATABASE $dbname;
QUERY
        mysql -u root --password="$dbpass" << QUERY
        CREATE DATABASE $dbname;
        GRANT ALL PRIVILEGES ON $dbname.* To '$dbuser'@'localhost' IDENTIFIED BY '$dbupass';
        FLUSH PRIVILEGES;
        SHOW GRANTS FOR '$dbuser'@'localhost';
QUERY
        # Recreate the schema.
        mysql -u $dbuser -p $dbname --password="$dbupass" < /var/www/MPOS/sql/000_base_structure.sql
        exit
  fi
  if [ $1 == "cleanup" ] ; then
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
        # Recreate the schema.
        mysql -u $dbuser -p $dbname --password="$dbupass" < /var/www/MPOS/sql/000_base_structure.sql
        exit
  fi
  echo "Invalid argument, exiting."
  exit
fi

################################################################################
#                               # Init #                                       #
################################################################################

apt-get update
apt-get dist-upgrade -y
apt-get autoremove -y
apt-get autoclean -y

################################################################################
#                               # Verium Wallet #                              #
################################################################################

# Install dependencies
apt install make g++ libminizip-dev libcurl4-openssl-dev unzip libboost-dev -y
apt install libboost-system-dev libboost-filesystem-dev libboost-program-options-dev -y
apt install libboost-thread-dev libssl-dev libdb++-dev libminiupnpc-dev -y
apt install libboost-all-dev libqrencode-dev freeglut3-dev -y
apt install git build-essential automake autoconf pkg-config -y
apt install libcurl4-openssl-dev libjansson-dev libssl-dev libgmp-dev -y

# Create user for the wallet.
echo ${walletusername}:${walletuserpassword}::::/home/${walletusername}:/bin/bash | newusers

# Grab and build executable.
WALLET_HOME="/home/${walletusername}"
WALLET_SRC_PATH=${WALLET_HOME}/verium/wallet

mkdir $WALLET_HOME/verium
git clone https://github.com/VeriumReserve/verium "${WALLET_SRC_PATH}"
cd $WALLET_SRC_PATH/src
make -f makefile.unix

if [ ! -f veriumd ]; then
    echo "Verium compilation failed.."
    exit
fi

# Setup the configuration file.
curl https://www.vericoin.info/downloads/verium.conf > verium.conf
echo " " >> $WALLET_SRC_PATH/src/verium.conf
echo "server=1" >> $WALLET_SRC_PATH/src/verium.conf
echo "listen=1" >> $WALLET_SRC_PATH/src/verium.conf
echo "daemon=1" >> $WALLET_SRC_PATH/src/verium.conf
echo "gen=0" >> $WALLET_SRC_PATH/src/verium.conf
echo "rpcuser=$walletrpcuser" >> $WALLET_SRC_PATH/src/verium.conf
echo "rpcpassword=$walletrpcpass" >> $WALLET_SRC_PATH/src/verium.conf
echo "rpcallowip=127.0.0.1" >> $WALLET_SRC_PATH/src/verium.conf
echo "rpcallowip=localhost" >> $WALLET_SRC_PATH/src/verium.conf
echo "rpcallowip=$walletrpcallowip" >> $WALLET_SRC_PATH/src/verium.conf
echo "rpcport=$walletrpcport" >> $WALLET_SRC_PATH/src/verium.conf

# Permission fix, because we ran everything as root.
sudo chown -R $walletusername:$walletusername $WALLET_HOME

# Bootstrap the wallet

su $walletusername <<EOF

echo "Starting server.."
"$WALLET_SRC_PATH"/src/veriumd -conf=$WALLET_SRC_PATH/src/verium.conf
sleep 120

echo "Initiating bootstrap.."
"$WALLET_SRC_PATH"/src/veriumd -conf=$WALLET_SRC_PATH/src/verium.conf bootstrap false

echo "Stopping server.."
"$WALLET_SRC_PATH"/src/veriumd -conf=$WALLET_SRC_PATH/src/verium.conf stop

echo "Starting server again.."
"$WALLET_SRC_PATH"/src/veriumd -conf=$WALLET_SRC_PATH/src/verium.conf

sleep 120

echo "The following should print out something else than 0.."
"$WALLET_SRC_PATH"/src/veriumd -conf=$WALLET_SRC_PATH/src/verium.conf getblockcount

echo "The address of this node is:"
"$WALLET_SRC_PATH"/src/veriumd -conf=$WALLET_SRC_PATH/src/verium.conf getaddressesbyaccount

# Store the address in a textfile in the home directory.
"$WALLET_SRC_PATH"/src/veriumd getaddressesbyaccount "" | awk '/"/ {print $1;}' | cut -d\" -f2 > ~/verium_address.txt
EOF

VRM_ADDRESS=$(cat "$WALLET_HOME/verium_address.txt")

################################################################################
#                               # MySQL Database                               #
################################################################################

export DEBIAN_FRONTEND='noninteractive'
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $dbpass"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $dbpass"
apt install mysql-server -y


cp /etc/mysql/my.cnf /etc/mysql/my.cnf.BAK
echo " " >> /etc/mysql/my.cnf
echo "[mysqld]" >> /etc/mysql/my.cnf
echo '!sql_mode='STRICT_TRANS_TABLES\,NO_ZERO_IN_DATE\,NO_ZERO_DATE\,ERROR_FOR_DIVISION_BY_ZERO\,NO_AUTO_CREATE_USER\,NO_ENGINE_SUBSTITUTION';' >> /etc/mysql/my.cnf
/etc/init.d/mysql restart

mysql -u root --password="$dbpass" << QUERY
    DELETE FROM mysql.user WHERE User='';
    DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
    DROP DATABASE IF EXISTS test;
    DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
    FLUSH PRIVILEGES;
QUERY

mysql -u root --password="$dbpass" << QUERY
    CREATE DATABASE $dbname;
    GRANT ALL PRIVILEGES ON $dbname.* To '$dbuser'@'localhost' IDENTIFIED BY '$dbupass';
    FLUSH PRIVILEGES;
    SHOW GRANTS FOR '$dbuser'@'localhost';
QUERY


################################################################################
#                               # Stratum #                                    #
################################################################################

apt-get install redis-server -y 

# Create the user.
echo ${stratumuser}:${stratumuserpassword}::::/home/${stratumuser}:/bin/bash | newusers

# Install NVM for the ancient node version.

su $stratumuser <<EOF
touch ~/.bashrc
curl https://raw.githubusercontent.com/creationix/nvm/v0.16.1/install.sh | sh

EOF

# We need to start a new shell for NVM to work.
su $stratumuser <<EOF
# Setup NVM.
source ~/.bashrc
nvm install 0.10
nvm use 0.10
nvm alias default 0.10

# Download NOMP
cd ~/
git clone https://github.com/zone117x/node-open-mining-portal nomp
cd nomp
sed -i 's/"request": "\*",/"request": "2.69.0",/g' package.json
npm update
cp config_example.json config.json
cp pool_configs/litecoin_example.json pool_configs/verium.json
echo "" > config.json
echo "" > pool_configs/verium.json

EOF

cat <<EOF > /home/$stratumuser/nomp/pool_configs/verium.json
{
    "enabled": true,
    "coin": "verium.json",

    "address": "${VRM_ADDRESS}",

    "paymentProcessing": {
        "enabled": false,
        "paymentInterval": 20,
        "minimumPayment": 70,
        "daemon": {
            "host": "127.0.0.1",
            "port": 19332,
            "user": "testuser",
            "password": "testpass"
        }
    },

    "ports": {
        "3332": {
            "diff": 0.001,
            "varDiff": {
              "minDiff": 0.001,
              "maxDiff": 0.03,
              "targetTime": 100,
              "retargetTime": 90,
              "variancePercent": 30

            }
        },
        "3333": {
            "diff": 0.03,
            "varDiff": {
                "minDiff": 0.03,
                "maxDiff": 0.2,
                "targetTime": 100,
                "retargetTime": 90,
                "variancePercent": 30
            }
        },
        "3334": {
            "diff": 0.2,
            "varDiff": {
                "minDiff": 0.02,
                "maxDiff": 0.06,
                "targetTime": 100,
                "retargetTime": 90,
                "variancePercent": 30
            }
        }
    },

    "daemons": [
        {
            "host": "127.0.0.1",
            "port": ${walletrpcport},
            "user": "${walletrpcuser}",
            "password": "${walletrpcpass}"
        }
    ],

    "p2p": {
        "enabled": false,
        "host": "127.0.0.1",
        "port": 19333,
        "disableTransactions": true
    },

    "mposMode": {
        "enabled": true,
        "host": "127.0.0.1",
        "port": 3306,
        "user": "${dbuser}",
        "password": "${dbupass}",
        "database": "${dbname}",
        "checkPassword": true,
        "autoCreateWorker": false
    }

}

EOF

cat <<EOF > /home/$stratumuser/nomp/coins/verium.json
{
    "name": "Verium",
    "symbol": "VRM",
    "algorithm": "scrypt-n",
    "reward":"POS",
    "timeTable": {
      "1048576": 100
    }
}

EOF

cat <<EOT > /home/$stratumuser/nomp/config.json

{
    "logLevel": "debug",
    "logColors": true,

    "cliPort": 17117,

    "clustering": {
        "enabled": true,
        "forks": "auto"
    },

    "defaultPoolConfigs": {
        "blockRefreshInterval": 1000,
        "jobRebroadcastTimeout": 55,
        "connectionTimeout": 600,
        "emitInvalidBlockHashes": false,
        "validateWorkerUsername": true,
        "tcpProxyProtocol": false,
        "banning": {
            "enabled": true,
            "time": 600,
            "invalidPercent": 50,
            "checkThreshold": 500,
            "purgeInterval": 300
        },
        "redis": {
            "host": "127.0.0.1",
            "port": 6379
        }
    },

    "website": {
        "enabled": false,
        "host": "0.0.0.0",
        "port": 80,
        "stratumHost": "cryppit.com",
        "stats": {
            "updateInterval": 60,
            "historicalRetention": 43200,
            "hashrateWindow": 300
        },
        "adminCenter": {
            "enabled": true,
            "password": "password"
        }
    },

    "redis": {
        "host": "127.0.0.1",
        "port": 6379
    },

    "switching": {
        "switch1": {
            "enabled": false,
            "algorithm": "sha256",
            "ports": {
                "3333": {
                    "diff": 10,
                    "varDiff": {
                        "minDiff": 16,
                        "maxDiff": 512,
                        "targetTime": 15,
                        "retargetTime": 90,
                        "variancePercent": 30
                    }
                }
            }
        },
        "switch2": {
            "enabled": false,
            "algorithm": "scrypt",
            "ports": {
                "4444": {
                    "diff": 10,
                    "varDiff": {
                        "minDiff": 16,
                        "maxDiff": 512,
                        "targetTime": 15,
                        "retargetTime": 90,
                        "variancePercent": 30
                    }
                }
            }
        },
        "switch3": {
            "enabled": false,
            "algorithm": "x11",
            "ports": {
                "5555": {
                    "diff": 0.001,
                    "varDiff": {
                        "minDiff": 0.001,
                        "maxDiff": 1,
                        "targetTime": 15,
                        "retargetTime": 60,
                        "variancePercent": 30
                    }
                }
            }
        }
    },

    "profitSwitch": {
        "enabled": false,
        "updateInterval": 600,
        "depth": 0.90,
        "usePoloniex": true,
        "useCryptsy": true,
        "useMintpal": true,
        "useBittrex": true
    }
}

EOT


################################################################################
#                               # PHP5 #                                       #
################################################################################

# PHP 5(.7)
apt-get purge `dpkg -l | grep php| awk '{print $2}' |tr "\n" " "` -y
add-apt-repository ppa:ondrej/php -y
apt-get install software-properties-common -y
apt-get update
apt-get install php5.6 -y

apt-get install memcached php5.6-memcached php5.6-mysqlnd php5.6-curl php5.6-json libapache2-mod-php5.6 -y
apache2ctl -k stop; sleep 2; sudo apache2ctl -k start

################################################################################
#                               # MPOS #                                       #
################################################################################


apt-get install apache2 -y 

Cd /var/www
git clone git://github.com/MPOS/php-mpos.git MPOS
cd MPOS
git checkout master

# Set permissions
chown -R www-data:www-data /var/www

# Setup the database.
mysql -u $dbuser -p $dbname --password="$dbupass" < /var/www/MPOS/sql/000_base_structure.sql

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

sed -i "s|\(\$config\['wallet'\]\['host'\] = \).*|\1'localhost:${walletrpcport}';|" include/config/global.inc.php
sed -i "s|\(\$config\['wallet'\]\['username'\] = \).*|\1'${walletrpcuser}';|" include/config/global.inc.php
sed -i "s|\(\$config\['wallet'\]\['password'\] = \).*|\1'${walletrpcpass}';|" include/config/global.inc.php

sed -i "s|\(\$config\['gettingstarted'\]\['coinname'\] = \).*|\1'Verium';|" include/config/global.inc.php
sed -i "s|\(\$config\['gettingstarted'\]\['coinurl'\] = \).*|\1'https://portal.vericoin.info/';|" include/config/global.inc.php
sed -i "s|\(\$config\['gettingstarted'\]\['stratumurl'\] = \).*|\1'${domain}';|" include/config/global.inc.php
sed -i "s|\(\$config\['gettingstarted'\]\['stratumport'\] = \).*|\1'3333';|" include/config/global.inc.php

sed -i "s|\(\$config\['ap_threshold'\]\['min'\] = \).*|\12;|" include/config/global.inc.php
sed -i "s|\(\$config\['ap_threshold'\]\['max'\] = \).*|\120;|" include/config/global.inc.php

sed -i "s|\(\$config\['currency'\] = \).*|\1'VRM';|" include/config/global.inc.php

sed -i "s|\(\$config\['reward'\] = \).*|\13\.8;|" include/config/global.inc.php

# Configure Apache (this assumes default vanilla Apache install)
sed -i 's|DocumentRoot .*|DocumentRoot /var/www/MPOS/public|' /etc/apache2/sites-available/default-ssl.conf
sed -i 's|DocumentRoot .*|DocumentRoot /var/www/MPOS/public|' /etc/apache2/sites-available/000-default.conf
systemctl restart apache2.service
