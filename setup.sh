#!/bin/bash
# --- 1. LOAD SECRETS ---
[ -f "/boot/secrets.txt" ] && source /boot/secrets.txt

# --- 2. SYSTEM & WOL ---
echo "root:$DIETPI_PASSWORD" | chpasswd
apt-get update && apt-get install -y ethtool openvpn sqlite3
echo -e "auto eth0\niface eth0 inet dhcp\n    ethernet-wol g" > /etc/network/interfaces.d/eth0
ethtool -s eth0 wol g

# --- 3. CONFIGURE VPN ---
echo -e "$EXPRESSVPN_USER\n$EXPRESSVPN_PASS" > /etc/openvpn/pass.txt
chmod 600 /etc/openvpn/pass.txt
wget -O /etc/openvpn/expressvpn.conf https://githubusercontent.com
sed -i 's|^auth-user-pass$|auth-user-pass /etc/openvpn/pass.txt|' /etc/openvpn/expressvpn.conf
systemctl enable openvpn@expressvpn

# --- 4. INSTALL SOFTWARE ---
dietpi-software install 130 137 134 135 146 162 96

# --- 5. APP SETUP & REVERSE PROXY PATHS ---
sqlite3 /var/lib/sonarr/sonarr.db "UPDATE Config SET Value = '/sonarr' WHERE Key = 'UrlBase';" || true
sqlite3 /var/lib/radarr/radarr.db "UPDATE Config SET Value = '/radarr' WHERE Key = 'UrlBase';" || true
sqlite3 /var/lib/prowlarr/prowlarr.db "UPDATE Config SET Value = '/prowlarr' WHERE Key = 'UrlBase';" || true

# --- 6. QUIET HOURS (02:00 - 07:00) ---
mkdir -p /home/dietpi/.config/qBittorrent/
cat << 'QBT' > /home/dietpi/.config/qBittorrent/qBittorrent.conf
[Preferences]
QueueingSystem\MaxActiveDownloads=3
Scheduler\Enabled=true
Scheduler\StartHour=2
Scheduler\EndHour=7
QBT

# --- 7. FORKS & PROCESSES ---
git clone https://github.com /home/dietpi/AIOStreams
cd /home/dietpi/AIOStreams && npm ci --omit=dev
git clone https://github.com /home/dietpi/AIOMetadata
cd /home/dietpi/AIOMetadata && npm ci --omit=dev

npm install -g pm2
pm2 start /home/dietpi/AIOStreams/index.js --name "aiostreams"
pm2 start /home/dietpi/AIOMetadata/index.js --name "aiometadata"
pm2 save
pm2 startup

# --- 8. STORAGE & SAMBA ---
mkdir -p /mnt/media
mount /dev/sdb1 /mnt/media
(echo "$SAMBA_PASSWORD"; echo "$SAMBA_PASSWORD") | smbpasswd -s -a root

echo "Setup Complete! Torbox API: $TORBOX_API_KEY"
