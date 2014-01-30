#! /bin/bash
#by marc brown - use at your own risk
source /tmp/settings.conf
echo "******************************************************************************************"
echo "******************************************************************************************"
echo "******************************************************************************************"
echo "*************This will install sabnzb, sickbeard, headphones                  ************"
echo "*************couchpotato, lazy librarian, ufw, fail2ban                       ************"
echo "*************,squid proxy server and curlftpfs with mount points for your     ************"
echo "*************home media colletcion this assumes you have the following folders************"
echo "*************kidstv,kidsfilms,dadstv,dadsfilms,music books and 1gig swap file ************"
echo "*************ubuntu 12.04 server this was written and tested on a ramnode vps ************"
echo "*************installed with 12.04 server minimal on a kvm virtual machine     ************"
echo "*************vm matters if you want fuse to work out of the box - curlftpfs   ************"
echo "*************MAKE SURE YOU HAVE FILLED IN settings.conf place everything      ************"
echo "************* in the /tmp/ folder                                             ************"
echo "******************************************************************************************"
echo "******************************************************************************************"
echo "******************************************************************************************"
sleep 7
HOSTIP=ifconfig | awk -F':' '/inet addr/&&!/127.0.0.1/{split($2,_," ");print _[1]}'
echo "i will be using the above host ip for setting up sab etc"
echo "we will add a user so we can stop using root"
sleep 2
if [ $(id -u) -eq 0 ]; then
	read -p "Enter username : " username
	read -s -p "Enter password : " password
	egrep "^$username" /etc/passwd >/dev/null
	if [ $? -eq 0 ]; then
		echo "$username exists!"
		exit 1
	else
		pass=$(perl -e 'print crypt($ARGV[0], "password")' $password)
		useradd -m -p $pass $username
		[ $? -eq 0 ] && echo "User has been added to system!" || echo "Failed to add a user!"
	fi
else
	echo "Only root may add a user to the system"
	exit 2
	fi

#read -p "Right were are ready to start are you sure you want to do this ? y/n :" -n 1 -r
#if [[ ! $REPLY =~ ^[Nn]$ ]]
#then
	#exit 1
#else
	#fi
#want this to be optional	
#echo "####################################################################"	
#echo "## Here we go starting with an apt-get update and apt-get upgrade ##"
#echo "####################################################################"
#sleep 3
apt-get update
#echo "upgrading"
#sleep 2
#apt-get upgrade -y

echo "####################"
echo "## installing ufw ##"
echo "####################"
sleep 2
apt-get install ufw -y
echo "opening ports"
sleep 2
echo "###############################"
echo "## opening ports on firewall ##"
echo "###############################"
sleep 2
ufw allow $SSHPORT
echo "opening old ssh port just for now to make sure we dont lose our connetcion"
sleep 2
ufw allow ssh
echo "opening new Sab web UI port"
sleep 2
sudo ufw allow $SABPORT
echo "opening new Sickbeard web UI port"
sleep 2
sudo ufw allow $SICKPORT
echo "opening new Couchpotato web UI port"
sleep 2
sudo ufw allow $COUCHPORT
echo "opening new Headphones web UI port"
sleep 2
sudo ufw allow $HEADPORT
echo "opening new Lazy Librarian web UI port"
sleep 2
sudo ufw allow $BOOKPORT
echo "opening new Squid Proxy server Port"
sleep 2
sudo ufw allow $SQUIDPORT
echo "editing sshd config"
sed -i "s/port 22/port $sshport/" /etc/ssh/sshd_config
sed -i "s/protocol 3,2/protocol 2/" /etc/ssh/sshd_config
sed -i "s/PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
sed -i "s/DebianBanner yes/DebianBanner no/" /etc/ssh/sshd_config
echo "restarting ssh"
sleep 2
/etc/init.d/ssh restart -y
echo "enabling firewall"
sleep 2
ufw enable -y

echo "##########################"
echo "## secure shared memory ##"
echo "##########################"
sleep 2
echo "tmpfs     /run/shm     tmpfs     defaults,noexec,nosuid     0     0" >> /etc/fstab
echo "adding admin group"
sleep 2
groupadd admin
usermod -a -G admin $username
dpkg-statoverride --update --add $username admin 4750 /bin/su

echo "############################################"
echo "# adding $username to sudo and fuse groups #"
echo "############################################"
sleep 3
usermod -a -G sudo $username
usermod -a -G fuse $username

echo "##########################"
echo "# IP Spoofing protetcion #"
echo "##########################"
sleep 3
cat > /etc/sysctl.conf << EOF
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1
# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
# Ignore send rediretcs
net.ipv4.conf.all.send_rediretcs = 0
net.ipv4.conf.default.send_rediretcs = 0
# Block SYN attacks
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5
# Log Martians
net.ipv4.conf.all.log_martians = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
# Ignore ICMP rediretcs
net.ipv4.conf.all.accept_rediretcs = 0
net.ipv6.conf.all.accept_rediretcs = 0
net.ipv4.conf.default.accept_rediretcs = 0
net.ipv6.conf.default.accept_rediretcs = 0
# Ignore Diretced pings
net.ipv4.icmp_echo_ignore_all = 1
EOF
sysctl -p

echo "#######################"
echo "# installing fail2ban #"
echo "#######################"
sleep 3
sudo apt-get install fail2ban -y
echo "setting up fail2ban"
sleep 2
sed -i 's/enabled = false/enabled = true/' /etc/fail2ban/jail.conf
sed -i 's/port = sshd/port = $SSHPORT/' /etc/fail2ban/jail.conf
sed -i 's/port = sshd/port = $SSHPORT/' /etc/fail2ban/jail.conf
sed -i 's/maxretry = 5/maxretry = 3/' /etc/fail2ban/jail.conf
echo "###########################################"
echo "#fail2ban installed and configured for ssh#"
echo "###########################################"
sleep 3

echo "###############################"
echo "#installing squid proxy server#"
echo "###############################"
sleep 3
sudo apt-get install -y squid3 squid3-common
echo "http_port $SQUIDPORT" >> /etc/squid3/squid.conf
echo "via off" >> /etc/squid3/squid.conf
echo "forwarded_for off" >> /etc/squid3/squid.conf
echo "request_header_access Allow allow all" >> /etc/squid3/squid.conf
echo "request_header_access Authorization allow all" >> /etc/squid3/squid.conf 
echo "request_header_access WWW-Authenticate allow all" >> /etc/squid3/squid.conf 
echo "request_header_access Proxy-Authorization allow all" >> /etc/squid3/squid.conf 
echo "request_header_access Proxy-Authenticate allow all" >> /etc/squid3/squid.conf 
echo "request_header_access Cache-Control allow all" >> /etc/squid3/squid.conf 
echo "request_header_access Content-Encoding allow all" >> /etc/squid3/squid.conf 
echo "request_header_access Content-Length allow all" >> /etc/squid3/squid.conf 
echo "request_header_access Content-Type allow all" >> /etc/squid3/squid.conf 
echo "request_header_access Date allow all" >> /etc/squid3/squid.conf 
echo "request_header_access Expires allow all" >> /etc/squid3/squid.conf 
echo "request_header_access Host allow all" >> /etc/squid3/squid.conf 
echo "request_header_access If-Modified-Since allow all" >> /etc/squid3/squid.conf 
echo "request_header_access Last-Modified allow all" >> /etc/squid3/squid.conf 
echo "request_header_access Location allow all" >> /etc/squid3/squid.conf 
echo "request_header_access Pragma allow all" >> /etc/squid3/squid.conf 
echo "request_header_access Accept allow all" >> /etc/squid3/squid.conf 
echo "request_header_access Accept-Charset allow all" >> /etc/squid3/squid.conf 
echo "request_header_access Accept-Encoding allow all" >> /etc/squid3/squid.conf 
echo "request_header_access Accept-Language allow all" >> /etc/squid3/squid.conf 
echo "request_header_access Content-Language allow all" >> /etc/squid3/squid.conf 
echo "request_header_access Mime-Version allow all" >> /etc/squid3/squid.conf 
echo "request_header_access Retry-After allow all" >> /etc/squid3/squid.conf 
echo "request_header_access Title allow all" >> /etc/squid3/squid.conf 
echo "request_header_access Connetcion allow all" >> /etc/squid3/squid.conf 
echo "request_header_access Proxy-Connetcion allow all" >> /etc/squid3/squid.conf 
echo "request_header_access User-Agent allow all" >> /etc/squid3/squid.conf 
echo "request_header_access Cookie allow all" >> /etc/squid3/squid.conf 
echo "request_header_access All deny all" >> /etc/squid3/squid.conf
echo "http_access allow ncsa_auth" >> /etc/squid3/squid.conf
sudo apt-get install apache2-utils
sudo echo "" >> /etc/squid3/squid_passwd
sudo touch /etc/squid3/squid_passwd
sudo chmod 777 /etc/squid3/squid_passwd
sudo htpasswd -b -c /etc/squid3/squid_user $SQUIDUSER $SQUIDPASS
echo "######################"
echo "#starting Squid Proxy#"
echo "######################"
sleep 2
service squid3 start
echo "####################################"
echo "# squid started on port $SQUIDPORT #"
echo "####################################"
sleep 3

echo "########################"
echo "# creating Diretcories #"
echo "########################"
sleep 2
mkdir /home/$username/.pid/
mkdir /home/downloads
mkdir /home/downloads/completed
mkdir /home/downloads/completed/tv
mkdir /home/downloads/completed/films
mkdir /home/downloads/completed/books
mkdir /home/downloads/completed/music
mkdir /home/downloads/ongoing
mkdir /home/media/
mkdir /home/media/kidstv
mkdir /home/media/kidsfilms
mkdir /home/media/dadstv
mkdir /home/media/dadsfilms
mkdir /home/media/music
mkdir /home/media/books
mkdir /home/backups/
mkdir /home/backups/sickbeard
mkdir /home/backups/couchpotato
mkdir /home/backups/headphones
mkdir /home/backups/lazylibrarian
mkdir /home/backups/sabnzbd
chown $username /home/*/*/
chmod 777  /home/*/*

echo "######################"
echo "# installing sabnzbd #"
echo "######################
sleep 3
sudo apt-get install -y sabnzbdplus
echo "making a copy in home dir"
sleep 2
mv /etc/default/sabnzbdplus /home/backups/sabnzbd/sabnzbdplus.orig
echo "change sab config"
sleep 2

cat > /etc/default/sabnzbdplus << EOF
USER=$username
CONFIG=
HOST=$HOSTIP
PORT=$HOSTPORT
EOF

chmod +x /etc/init.d/sabnzbdplus
echo "starting sabnzbplus"
/etc/init.d/sabnzbdplus start
echo "sabnzbdplus is now running on $HOSTIP:$SABPORT"

echo "########################"
echo "# installing sickbeard "
echo "########################"
mkdir /home/$username/temp
cd /home/$username/temp
apt-get install -y git
git clone https://github.com/midgetspy/Sick-Beard.git sickbeard
echo "backing up sickbeard"
sleep 2
cp sickbeard /home/backups/sickbeard
mv sickbeard /home/$username/.sickbeard
#cp /home/$username/.sickbeard/config.ini /etc/default/sickbeard
cp /home/$username/.sickbeard/init.ubuntu /etc/init.d/sickbeard
cat > /etc/init.d/sickbeard << EOF
#Optional -- Unneeded unless you have added a user name and password to Sick Beard
SBUSR="$WEBUSER" #Set Sick Beard user name (if you use one) here." >> /etc/init.d/sickbeard
SBPWD="$WEBPASS" #Set Sick Beard password (if you use one) here." >> /etc/init.d/sickbeard
#Script -- No changes needed below." >> /etc/init.d/sickbeard
case "$1" in"
echo "start)"
#Start Sick Beard and send all messages to /dev/null.
cd /home/$USER/.sickbeard" >> /etc/init.d/sickbeard
echo "Starting Sick Beard"" >> /etc/init.d/sickbeard
sudo -u $USER -EH nohup python /home/$USER/.sickbeard/SickBeard.py -q &gt; /dev/null 2&gt;&amp;1 &amp;" >> /etc/init.d/sickbeard
;;
stop)
#Shutdown Sick Beard and delete the index.html files that wget generates.
echo "Stopping Sick Beard"" >> /etc/init.d/sickbeard
wget -q --user=$SBUSR --password=$SBPWD "http://$HOST:$PORT/home/shutdown/" --delete-after
sleep 6s
;;
*)
echo "Usage: $0 {start|stop}"
exit 1
esac
exit 0
EOF

chmod +x /etc/init.d/sickbeard
sudo update-rc.d sickbeard defaults
sudo /etc/init.d/sickbeard stop
sudo /etc/init.d/sickbeard start
echo "sick beard is now running on $HOSTIP:$SICKPORT"

echo "###########################"
echo "# installling Couchpotato #"
echo "###########################"
sleep 3
cd /home/$username/temp
git clone https://github.com/RuudBurger/CouchPotatoServer.git couchpotato
cp couchpotato /home/$username/backups/couchpotato
mv couchpotato /home/$username/.couchpotato
cp /home/$username/.couchpotato/init/ubuntu /etc/init.d/couchpotato
touch /etc/default/couchpotato
echo "CP_HOME=/home/$username/.couchpotato" > /etc/default/couchpotato
echo "CP_USER=$username" >> /etc/default/couchpotato
echo "CP_DATA=/home/$username/.config/couchpotato >> /etc/default/couchpotato
echo "CP_PIDFILE=/home/$username/.pid/couchpotato.pid >> /etc/default/couchpotato
chmod +x /etc/init.d/couchpotato
sudo update-rc.d couchpotato defaults
echo "starting couchpotato"
python /home/$username/.couchpotato/CouchPotato.py --daemon
echo "CouchPotato has been started on port $COUCHPORT"

echo "#########################"
echo "# installing Headphones #"
echo "#########################"
sleep 3
cd /home/$username/temp
git clone https://github.com/rembo10/headphones.git  headphones
cp /home/$username/temp/headphones /home/backups/headphones/
mv /home/$username/temp/headphones /home/$username/.headphones
sudo cp /home/$username/.headphones/init.ubuntu /etc/init.d/headphones
mv /home/$username/.headphones/config.ini /home/$username/.headphones/config.orig
touch /home/$username/.headphones/config.ini
chown $username /home/$username/.headphones/*
chown $username /home/$username/.headphones/*/*
chmod 777 /home/$username/
echo "[General]" > /home/$username/.headphones/config.ini
echo "config_version = 5" >> /home/$username/.headphones/config.ini
echo "http_port = $HEADPORT" >> /home/$username/.headphones/config.ini
echo "http_host = $HOSTIP" >> /home/$username/.headphones/config.ini
echo "http_username = $WEBUSER" >> /home/$username/.headphones/config.ini
echo "http_password = $WEBPASS" >> /home/$username/.headphones/config.ini
echo "http_root = /" >> /home/$username/.headphones/config.ini
echo "http_proxy = 0" >> /home/$username/.headphones/config.ini
echo "enable_https = 0" >> /home/$username/.headphones/config.ini
echo "https_cert = /home/castro/.headphones/server.crt" >> /home/$username/.headphones/config.ini
echo "https_key = /home/castro/.headphones/server.key" >> /home/$username/.headphones/config.ini
echo "launch_browser = 1" >> /home/$username/.headphones/config.ini
echo "api_enabled = 0" >> /home/$username/.headphones/config.ini
echo "api_key = """ >> /home/$username/.headphones/config.ini
echo "log_dir = /home/$username/.headphones/logs" >> /home/$username/.headphones/config.ini
echo "cache_dir = /home/$username/.headphones/cache" >> /home/$username/.headphones/config.ini
echo "git_path = """ >> /home/$username/.headphones/config.ini
echo "git_user = rembo10" >> /home/$username/.headphones/config.ini
echo "git_branch = master" >> /home/$username/.headphones/config.ini
echo "check_github = 1" >> /home/$username/.headphones/config.ini
echo "check_github_on_startup = 1" >> /home/$username/.headphones/config.ini
echo "check_github_interval = 360" >> /home/$username/.headphones/config.ini
echo "music_dir = /home/music" >> /home/$username/.headphones/config.ini
echo "destination_dir = /home/music" >> /home/$username/.headphones/config.ini
echo "lossless_destination_dir = """ >> /home/$username/.headphones/config.ini
echo "preferred_quality = 0" >> /home/$username/.headphones/config.ini
echo "preferred_bitrate = """ >> /home/$username/.headphones/config.ini
echo "preferred_bitrate_high_buffer = """ >> /home/$username/.headphones/config.ini
echo "preferred_bitrate_low_buffer = """ >> /home/$username/.headphones/config.ini
echo "preferred_bitrate_allow_lossless = 0" >> /home/$username/.headphones/config.ini
echo "detetc_bitrate = 0" >> /home/$username/.headphones/config.ini
echo "auto_add_artists = 1" >> /home/$username/.headphones/config.ini
echo "corretc_metadata = 1" >> /home/$username/.headphones/config.ini
echo "move_files = 1" >> /home/$username/.headphones/config.ini
echo "rename_files = 1" >> /home/$username/.headphones/config.ini
echo "folder_format = $Artist/$Album [$Year]" >> /home/$username/.headphones/config.ini
echo "file_format = $Track $Artist - $Album [$Year] - $Title" >> /home/$username/.headphones/config.ini
echo "file_underscores = 0" >> /home/$username/.headphones/config.ini
echo "cleanup_files = 1" >> /home/$username/.headphones/config.ini
echo "add_album_art = 1" >> /home/$username/.headphones/config.ini
echo "album_art_format = folder" >> /home/$username/.headphones/config.ini
echo "embed_album_art = 1" >> /home/$username/.headphones/config.ini
echo "embed_lyrics = 0" >> /home/$username/.headphones/config.ini
echo "nzb_downloader = 0" >> /home/$username/.headphones/config.ini
echo "torrent_downloader = 0" >> /home/$username/.headphones/config.ini
echo "download_dir = /home/completed/music" >> /home/$username/.headphones/config.ini
echo "blackhole_dir = """ >> /home/$username/.headphones/config.ini
echo "usenet_retention = 1200" >> /home/$username/.headphones/config.ini
echo "include_extras = 0" >> /home/$username/.headphones/config.ini
echo "extras = """ >> /home/$username/.headphones/config.ini
echo "autowant_upcoming = 1" >> /home/$username/.headphones/config.ini
echo "autowant_all = 0" >> /home/$username/.headphones/config.ini
echo "keep_torrent_files = 0" >> /home/$username/.headphones/config.ini
echo "numberofseeders = 10" >> /home/$username/.headphones/config.ini
echo "torrentblackhole_dir = /home/torrents" >> /home/$username/.headphones/config.ini
echo "isohunt = 0" >> /home/$username/.headphones/config.ini
echo "kat = 1" >> /home/$username/.headphones/config.ini
echo "mininova = 0" >> /home/$username/.headphones/config.ini
echo "piratebay = 1" >> /home/$username/.headphones/config.ini
echo "piratebay_proxy_url = """ >> /home/$username/.headphones/config.ini
echo "download_torrent_dir = /home/completed/music" >> /home/$username/.headphones/config.ini
echo "search_interval = 360" >> /home/$username/.headphones/config.ini
echo "libraryscan = 1" >> /home/$username/.headphones/config.ini
echo "libraryscan_interval = 1800" >> /home/$username/.headphones/config.ini
echo "download_scan_interval = 5" >> /home/$username/.headphones/config.ini
echo "preferred_words = """ >> /home/$username/.headphones/config.ini
echo "ignored_words = """ >> /home/$username/.headphones/config.ini
echo "required_words = """ >> /home/$username/.headphones/config.ini
echo "lastfm_username = """ >> /home/$username/.headphones/config.ini
echo "interface = default" >> /home/$username/.headphones/config.ini
echo "folder_permissions = 0755" >> /home/$username/.headphones/config.ini
echo "file_permissions = 0644" >> /home/$username/.headphones/config.ini
echo "music_encoder = 0" >> /home/$username/.headphones/config.ini
echo "encoder = ffmpeg" >> /home/$username/.headphones/config.ini
echo "xldprofile = """ >> /home/$username/.headphones/config.ini
echo "bitrate = 192" >> /home/$username/.headphones/config.ini
echo "samplingfrequency = 44100" >> /home/$username/.headphones/config.ini
echo "encoder_path = """ >> /home/$username/.headphones/config.ini
echo "advancedencoder = """ >> /home/$username/.headphones/config.ini
echo "encoderoutputformat = mp3" >> /home/$username/.headphones/config.ini
echo "encoderquality = 2" >> /home/$username/.headphones/config.ini
echo "encodervbrcbr = cbr" >> /home/$username/.headphones/config.ini
echo "encoderlossless = 1" >> /home/$username/.headphones/config.ini
echo "delete_lossless_files = 1" >> /home/$username/.headphones/config.ini
echo "mirror = headphones" >> /home/$username/.headphones/config.ini
echo "customhost = localhost" >> /home/$username/.headphones/config.ini
echo "customport = 5000" >> /home/$username/.headphones/config.ini
echo "customsleep = 1" >> /home/$username/.headphones/config.ini
echo "hpuser = " >> /home/$username/.headphones/config.ini
echo "hppass = " >> /home/$username/.headphones/config.ini
echo "[Waffles]" >> /home/$username/.headphones/config.ini
echo "waffles = 0" >> /home/$username/.headphones/config.ini
echo "waffles_uid = """ >> /home/$username/.headphones/config.ini
echo "waffles_passkey = """ >> /home/$username/.headphones/config.ini
echo "[Rutracker]" >> /home/$username/.headphones/config.ini
echo "rutracker = 0" >> /home/$username/.headphones/config.ini
echo "rutracker_user = """ >> /home/$username/.headphones/config.ini
echo "rutracker_password = """ >> /home/$username/.headphones/config.ini
echo "[What.cd]" >> /home/$username/.headphones/config.ini
echo "whatcd = 0" >> /home/$username/.headphones/config.ini
echo "whatcd_username = """ >> /home/$username/.headphones/config.ini
echo "whatcd_password = """ >> /home/$username/.headphones/config.ini
echo "[SABnzbd]" >> /home/$username/.headphones/config.ini
echo "sab_host = http://$HOSTIP:$SABPORT/sabnzbd" >> /home/$username/.headphones/config.ini
echo "sab_username = $WEBUSER" >> /home/$username/.headphones/config.ini
echo "sab_password = $WEBPASS" >> /home/$username/.headphones/config.ini
echo "sab_apikey = " >> /home/$username/.headphones/config.ini
echo "sab_category = Music" >> /home/$username/.headphones/config.ini
echo "[NZBget]" >> /home/$username/.headphones/config.ini
echo "nzbget_username = nzbget" >> /home/$username/.headphones/config.ini
echo "nzbget_password = """ >> /home/$username/.headphones/config.ini
echo "nzbget_category = """ >> /home/$username/.headphones/config.ini
echo "nzbget_host = """ >> /home/$username/.headphones/config.ini
echo "[Headphones]" >> /home/$username/.headphones/config.ini
echo "headphones_indexer = 1" >> /home/$username/.headphones/config.ini
echo "[Transmission]" >> /home/$username/.headphones/config.ini
echo "transmission_host =" >> /home/$username/.headphones/config.ini
echo "transmission_username =" >> /home/$username/.headphones/config.ini
echo "transmission_password =" >> /home/$username/.headphones/config.ini
echo "[uTorrent]" >> /home/$username/.headphones/config.ini
echo "utorrent_host = """ >> /home/$username/.headphones/config.ini
echo "utorrent_username = """ >> /home/$username/.headphones/config.ini
echo "utorrent_password = """ >> /home/$username/.headphones/config.ini
echo "[Newznab]" >> /home/$username/.headphones/config.ini
echo "newznab = 1" >> /home/$username/.headphones/config.ini
echo "newznab_host = http://$HOSTIP" >> /home/$username/.headphones/config.ini
echo "newznab_apikey =" >> /home/$username/.headphones/config.ini
echo "newznab_enabled = 1" >> /home/$username/.headphones/config.ini
echo "extra_newznabs =" >> /home/$username/.headphones/config.ini
echo "[NZBsorg]" >> /home/$username/.headphones/config.ini
echo "nzbsorg = 0" >> /home/$username/.headphones/config.ini
echo "nzbsorg_uid = None" >> /home/$username/.headphones/config.ini
echo "nzbsorg_hash = """ >> /home/$username/.headphones/config.ini
echo "[NZBsRus]" >> /home/$username/.headphones/config.ini
echo "nzbsrus = 0" >> /home/$username/.headphones/config.ini
echo "nzbsrus_uid = """ >> /home/$username/.headphones/config.ini
echo "nzbsrus_apikey = """ >> /home/$username/.headphones/config.ini
echo "[Prowl]" >> /home/$username/.headphones/config.ini
echo "prowl_enabled = 0" >> /home/$username/.headphones/config.ini
echo "prowl_keys = """ >> /home/$username/.headphones/config.ini
echo "prowl_onsnatch = 0" >> /home/$username/.headphones/config.ini
echo "prowl_priority = 0" >> /home/$username/.headphones/config.ini
echo "[XBMC]" >> /home/$username/.headphones/config.ini
echo "xbmc_enabled = 0" >> /home/$username/.headphones/config.ini
echo "xbmc_host = """ >> /home/$username/.headphones/config.ini
echo "xbmc_username = """ >> /home/$username/.headphones/config.ini
echo "xbmc_password = """ >> /home/$username/.headphones/config.ini
echo "xbmc_update = 0" >> /home/$username/.headphones/config.ini
echo "xbmc_notify = 0" >> /home/$username/.headphones/config.ini
echo "[NMA]" >> /home/$username/.headphones/config.ini
echo "nma_enabled = 0" >> /home/$username/.headphones/config.ini
echo "nma_apikey = """ >> /home/$username/.headphones/config.ini
echo "nma_priority = 0" >> /home/$username/.headphones/config.ini
echo "nma_onsnatch = 0" >> /home/$username/.headphones/config.ini
echo "[Pushover]" >> /home/$username/.headphones/config.ini
echo "pushover_enabled = 0" >> /home/$username/.headphones/config.ini
echo "pushover_keys = """ >> /home/$username/.headphones/config.ini
echo "pushover_onsnatch = 0" >> /home/$username/.headphones/config.ini
echo "pushover_priority = 0" >> /home/$username/.headphones/config.ini
echo "[Synoindex]" >> /home/$username/.headphones/config.ini
echo "synoindex_enabled = 0" >> /home/$username/.headphones/config.ini
echo "[Advanced]" >> /home/$username/.headphones/config.ini
echo "album_completion_pct = 80" >> /home/$username/.headphones/config.ini
echo "cache_sizemb = 32" >> /home/$username/.headphones/config.ini
echo "journal_mode = wal" >> /home/$username/.headphones/config.ini
cp /home/$username/.headphones/config.ini /etc/default/headphones
chown $username /home/$username/.headphones/
chown $username /home/$username/.headphones/*
chown $username /home/$username/.headphones/*/*
chmod 777 /home/$username/.headphones/*
chown $username /home/$userna
chmod +x /etc/init.d/headphones  
update-rc.d headphones defaults  
echo "starting Headphones on port $HEADPORT"   
python /home/$username/.headphones/Headphones.py --daemon
echo "Headphones has started you can try http://$HOSTIP:$HEADPORT"

echo "############################"
echo "# installing Lazylibrarian #"
echo "############################"
cd /home/$username/temp
git clone https://github.com/Conjuro/LazyLibrarian.git lazylibrarian 
cp /home/$username/temp/lazylibrarian /home/backups/lazylibrarian/
mv /home/$username/temp/lazylibrarian  /home/$username/.lazylibrarian 
cp /home/$username/.lazylibrarian/init/ubuntu.initd /etc/init.d/lazylibrarian 
#cp /home/$username/.lazylibrarian/init/ubuntu.default /etc/default/lazylibrarian
echo "APP_PATH=/home/castro/.lazylibrarian" > /etc/default/lazylibrarian
echo "ENABLE_DAEMON=1" >> /etc/default/lazylibrarian
echo "RUN_AS=$user" >> /etc/default/lazylibrarian
echo "WEBUPDATE=0" >> /etc/default/lazylibrarian
echo "CONFIG=/home/$username/.lazylibrarian/" >> /etc/default/lazylibrarian
echo "DATADIR=/home/$username/.lazylibrarian/" >> /etc/default/lazylibrarian
echo "PORT=$BOOKPORT" >> /etc/default/lazylibrarian
echo "PID_FILE=/home/$username/.lazylibrarian/lazylibrarian.pid" >> /etc/default/lazylibrarian
chown $username /home/$username/.lazylibrarian
chmod 777 /home/$username/.lazylibrarian
chmod +x /etc/init.d/lazylibrarian  
update-rc.d lazylibrarian  defaults  
echo "starting Lazy Librarian on port $BOOKPORT"
python /home/$username/.lazylibrarian/LazyLibrarian.py --daemon
echo "Lazy Librarian has started you can try http://$HOSTIP:$BOOKPORT"
sleep 2

echo "########################"
echo "# installing curlftpfs #"
echo "########################"
sleep 2
sudo apt-get install curlftpfs

echo "########################"
echo "#   add mount points   #"
echo "########################"
echo "curlftpfs#$FTPUSER:$FTPPASS@$FTPHOST/$FILMFTPDIR /home/media/films fuse auto,user,uid=1000,allow_other,_netdev 0 0" >> /etc/fstab
echo "curlftpfs#$FTPUSER:$FTPPASS@$FTPHOST/$TVFTPDIR /home/media/tv fuse auto,user,uid=1000,allow_other,_netdev 0 0" >> /etc/fstab
echo "curlftpfs#$FTPUSER:$FTPPASS@$FTPHOST/$MUSICFTPDIR /home/media/music fuse auto,user,uid=1000,allow_other,_netdev 0 0" >> /etc/fstab
echo "curlftpfs#$FTPUSER:$FTPPASS@$FTPHOST/$BOOKFTPDIR /home/books fuse auto,user,uid=1000,allow_other,_netdev 0 0" >> /etc/fstab

echo "######################"
echo "# add 1GB swap space #"
echo "######################"
sleep 2
sudo dd if=/dev/zero of=/swapfile bs=1024 count=1024k
sudo mkswap /swapfile
sudo swapon /swapfile
echo "/swapfile       none    swap    sw      0       0" >> /etc/fstab
echo 0 | sudo tee /proc/sys/vm/swappiness
echo vm.swappiness = 0 | sudo tee -a /etc/sysctl.conf
echo "mounting ftp locations"
sleep 2
sudo mount -a
echo "Thats it i am done lets check how well we did Adios"
sleep 10
sudo ufw deny 22
fi
