#!/bin/bash
set -e
[ -f "/boot/secrets.txt" ] && source /boot/secrets.txt
echo "root:${DIETPI_PASSWORD:-dietpi}" | chpasswd
apt-get update && apt-get install -y ethtool openvpn sqlite3
printf 'auto eth0\niface eth0 inet dhcp\n    ethernet-wol g\n' > /etc/network/interfaces.d/eth0
ethtool -s eth0 wol g
mkdir -p /etc/openvpn
printf '%s\n%s\n' "${EXPRESSVPN_USER}" "${EXPRESSVPN_PASS}" > /etc/openvpn/pass.txt
chmod 600 /etc/openvpn/pass.txt
wget -q -O /etc/openvpn/expressvpn.conf "https://raw.githubusercontent.com/ajdhoward/nas-config/master/my_expressvpn_switzerland_udp.ovpn"
sed -i 's|^auth-user-pass$|auth-user-pass /etc/openvpn/pass.txt|' /etc/openvpn/expressvpn.conf
systemctl enable openvpn@expressvpn 2>/dev/null || true
dietpi-software install 130 137 134 135 146 162 96
sqlite3 /var/lib/sonarr/sonarr.db "UPDATE Config SET Value='/sonarr' WHERE Key='UrlBase';" 2>/dev/null || true
sqlite3 /var/lib/radarr/radarr.db "UPDATE Config SET Value='/radarr' WHERE Key='UrlBase';" 2>/dev/null || true
sqlite3 /var/lib/prowlarr/prowlarr.db "UPDATE Config SET Value='/prowlarr' WHERE Key='UrlBase';" 2>/dev/null || true
git clone https://github.com/ajdhoward/AIOStreams /home/dietpi/AIOStreams
cd /home/dietpi/AIOStreams && npm ci --omit=dev
git clone https://github.com/ajdhoward/AIOMetadata /home/dietpi/AIOMetadata
cd /home/dietpi/AIOMetadata && npm ci --omit=dev
npm install -g pm2
pm2 start /home/dietpi/AIOStreams/index.js --name "aiostreams"
pm2 start /home/dietpi/AIOMetadata/index.js --name "aiometadata"
pm2 save
pm2 startup
mkdir -p /mnt/media
mount /dev/sdb1 /mnt/media
(echo "$SAMBA_PASSWORD"; echo "$SAMBA_PASSWORD") | smbpasswd -s -a root
