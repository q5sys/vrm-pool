# Verium Mining Pool Scripts

This repo contains a bunch of scripts that should aid in installing a Verium
mining pool. They are grouped together in their respective subfolders in
`scripts/`.

These scripts have been tested on an Ubuntu 16.04 vanilla install.

Each of these scripts generates passwords at random. Each password will be
stored in `/root/<service>_passwords.txt`, where `service` is the relevant
serivice (i.e., `mysql`, `veriumd`, or `nomp`).

## Known Problems

I have had some issues when I installed mysql-server before the veriumd
wallet. That would result in compilation issues. Not sure how that happened, but
be sure to install veriumd before mysql..

## Veriumd

Veriumd is the daemon that runs the verium wallet. Installing it is pretty
straightforward. Run the `install.sh` script in `scripts/veriumd` and wait for
it to finish.

All the passwords will be stored in `/root/veriumd_passwords.txt`. The first
password will be the unix user password, and the second is the veriumd rpc
password.

You can make the system startup by copying the systemd file located at
`systemd/veriumd.service` to `/etc/systemd/system/`, and then start it by typing
`systemctl start veriumd.service`.

Once the service is online, you can bootstrap it by issueing `veriumd
-conf=/etc/veriumd/verium.conf bootstrap false`, and afterwards restart the
service.

You can verify the system works by executing `vveriumd
-conf=/etc/veriumd/verium.conf getinfo`. Be patient here, it might take a while.

### Credentials

The RPC username is `veriumrpc`, and the password is stored in the
aforementioned textfile.

The unix username is `veriumd`, and the password is stored in the aforementioned
textfile.




## MySQL Server

MySQL server is installed by running `scripts/mysql/install.sh`.

### Credentials

The root password is stored in `/root/mysql_password.txt`.


## Nomp

Nomp is the stratum software that divides work up between all the users of your
pool.

It requires node.js 0.10 to run, so we will be using `nvm` to install that for
us.

Run it by executing `scripts/nomp/install.sh`.

The script will install `nvm` for the `nomp` user.

You can verify the system works by doing the following.

```
su nomp
cd ~/nomp
node init.js
```

You should see no errors, maybe except the one for paymentPRocessing.

One thing you should configure is the verium wallet address. Normally, you can
get the veriumd address by issuing the following command.

```
veriumd -conf=/etc/veriumd/verium.conf getaddressesbyaccount "" | awk '/"/ {print $1;}' | cut -d\" -f2 > ~/verium_address.txt
```

This will put the verium address in a text file. Place the contents of that file
into the configuration file located at
`/home/nomp/nomp/pool_config/verium.json`.

Finally, you should fill in the daemon credentials for the veriumd service into
the same file.

### Credentials 

The unix user for nomp is `nomp`, and its password is stored in
`/root/nomp_passwords.txt`.

We also have a password for the database user (`nompuser`).


## MPOS

MPOS is the webinterface part for the mining pool. This requires some additional setup.

First run the script in `scripts/mpos/install.sh`.

Finally, you need to change some values in the configuration file of MPOS. This is located at `/var/www/MPOS/include/config/global.inc.php`.

The lines you need to change are the following. You need the RPC password, which is stored in `/root/veriumd_passwords.txt`.

```
$config['wallet']['password'] = 'rpcpasswordhere'; // Insert your RPC password here.

$config['gettingstarted']['stratumurl'] = 'yourdomainhere.com';
```

## Mail

You will need to setup your server to be able to send emails to users. In this guide we are going to use a third-party smtp server. Chances are, if you are a member of gandi.net or others, you can just use their SMTP server. This guide assumes gandi.net, since that is where I have taken out my domain name.

```
apt-get install postfix mailutils
```

When asked, select `Internet Site`, and when asked for your hostname, enter your full domain name. For example `myserver.mydomain.com`.


Create the file `/etc/postfix/sasl_passwd`. Assuming the SMTP you can use its IP is `mail.gandi.net`, and the username for your account is `myusername@gandi.net` and `mypassword`, add this line:

```
[mail.gandi.net]:587 myusername@gadni.net:mypassword
```

after you have done that, run 

```
sudo postmap /etc/postfix/sasl_passwd
```

Note that you now have your SMTP credentials as *plain text* on your server. Secure this as much as possible.

```
sudo chown root:root /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db
sudo chmod 0600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db

```

Then open up the file `/etc/postfix/main.cf` and add the following lines.

```
myhostname = myserver.mydomain.com
relayhost = [mail.gandi.net]:587
```

After all this, you should be able to send an e-mail to yourself. Try this out:

```
echo "body of your email" | mail -s "This is a Subject" -a "From: pool@pool.com" me@me.com
```

## Cronjobs

MPOS requires you to run some cronjobs. Mostly for paying out your users (important, no?), and statistics. You can just smack those into your crontab. You can edit it with `sudo crontab -e`.

Add the following lines:

```
* * * * * /var/www/MPOS/cronjobs/run-statistics.sh
* * * * * /var/www/MPOS/cronjobs/run-payout.sh 
* * * * * /var/www/MPOS/cronjobs/run-maintenance.sh 
```

