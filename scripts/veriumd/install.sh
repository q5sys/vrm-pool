#!/bin/bash
set -euo

# Script must be run as root.
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root, exiting." 
   exit 1
fi


###########################
# Setup the unix account. #
###########################

NIX_NAME="veriumd"
NIX_PASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 128 ; echo '')
RPC_PASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 128 ; echo '')

echo "veriumd user password: ${NIX_PASS}"
echo "NIX: ${NIX_PASS}" > /root/veriumd_passwords.txt
echo "RPC: ${RPC_PASS}" >> /root/veriumd_passwords.txt

echo "${NIX_NAME}":"${NIX_PASS}"::::/home/${NIX_NAME}:/bin/bash | newusers


########################
# Install dependencies #
########################

apt-get install build-essential libboost-dev libboost-system-dev -y
apt-get install libboost-filesystem-dev libboost-program-options-dev -y
apt-get install libboost-thread-dev libssl-dev libdb++-dev -y
apt-get install libminiupnpc-dev libboost-all-dev libqrencode-dev -y
apt-get install freeglut3-dev git libcurl4-gnutls-dev libminizip-dev -y

######################
# Compile the wallet #
######################

# Grab and build executable.
WALLET_HOME="/home/${NIX_NAME}"
WALLET_SRC_PATH=${WALLET_HOME}/veriumd/

mkdir $WALLET_HOME/veriumd

git clone https://github.com/VeriumReserve/verium "${WALLET_SRC_PATH}"
cd $WALLET_SRC_PATH/src
make -f makefile.unix -j8

if [ ! -f veriumd ]; then
    echo "Verium compilation failed.."
    exit
fi

###############################
# Link and create config file #
###############################

mkdir -p /etc/veriumd/
wget http://www.vericoin.info/downloads/verium.conf -O /etc/veriumd/verium.conf
chown -R ${NIX_NAME}:${NIX_NAME} /etc/veriumd
chmod 640 /etc/veriumd/verium.conf

ln -s "${WALLET_SRC_PATH}/src/veriumd" /usr/bin/veriumd

#################
# Intial config #
#################

{
  echo " " 
  echo "server=1" 
  echo "listen=1" 
  echo "daemon=1" 
  echo "gen=0" 
  echo "rpcuser=veriumrpc" 
  echo "rpcpassword=${RPC_PASS}" 
  echo "rpcallowip=127.0.0.1" 
  echo "rpcallowip=localhost" 
  echo "rpcallowip="
  echo "rpcport=33987"
} >> /etc/veriumd/verium.conf

chown -R veriumd:veriumd /etc/veriumd
chmod -R 755 /etc/veriumd
