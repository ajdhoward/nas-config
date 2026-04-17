#!/bin/bash
set -e
[ -f "/boot/secrets.txt" ] && source /boot/secrets.txt
echo "root:${DIETPI_PASSWORD:-dietpi}" | chpasswd
apt-get update && apt-get install -y ethtool openvpn sqlite3
printf 'auto eth0\niface eth0 inet dhcp\n    ethernet-wol g\n' > /etc/network/interfaces.d/eth0
ethtool -s eth0 wol g
MEDIA_DEV=$(lsblk -bndo NAME,SIZE 2>/dev/null | awk '$2 > 2000000000000 {print "/dev/"$1; exit}')
if [ -n "$MEDIA_DEV" ]; then
  MEDIA_PART="${MEDIA_DEV}1"
  MEDIA_UUID=$(blkid -s UUID -o value "$MEDIA_PART" 2>/dev/null || true)
  [ -n "$MEDIA_UUID" ] && mkdir -p /mnt/media && echo "UUID=$MEDIA_UUID /mnt/media ext4 defaults,noatime 0 2" >> /etc/fstab && mount -a || true
fi
mkdir -p /etc/openvpn
printf '%s\n%s\n' "${EXPRESSVPN_USER}" "${EXPRESSVPN_PASS}" > /etc/openvpn/pass.txt
wget -q -O /etc/openvpn/expressvpn.conf "https://raw.githubusercontent.com/ajdhoward/nas-config/master/my_expressvpn_switzerland_udp.ovpn"
sed -i 's|^auth-user-pass$|auth-user-pass /etc/openvpn/pass.txt|' /etc/openvpn/expressvpn.conf
systemctl enable openvpn@expressvpn
dietpi-software install 130 137 134 135 146 162 96
sqlite3 /home/dietpi/.config/Sonarr/sonarr.db "UPDATE Config SET Value='/sonarr' WHERE Key='UrlBase';" || true
sqlite3 /home/dietpi/.config/Radarr/radarr.db "UPDATE Config SET Value='/radarr' WHERE Key='UrlBase';" || true
sqlite3 /home/dietpi/.config/Prowlarr/prowlarr.db "UPDATE Config SET Value='/prowlarr' WHERE Key='UrlBase';" || true
git clone https://github.com/ajdhoward/AIOStreams /home/dietpi/AIOStreams
cd /home/dietpi/AIOStreams && npm ci --omit=dev
git clone https://github.com/ajdhoward/AIOMetadata /home/dietpi/AIOMetadata
cd /home/dietpi/AIOMetadata && npm ci --omit=dev
npm install -g pm2
pm2 start /home/dietpi/AIOStreams/index.js --name "aiostreams"
pm2 start /home/dietpi/AIOMetadata/index.js --name "aiometadata"
pm2 save && pm2 startup
(echo "${SAMBA_PASSWORD:-dietpi}"; echo "${SAMBA_PASSWORD:-dietpi}") | smbpasswd -s -a root
echo "✅ NAS setup complete!"
