#!/bin/bash
set -e

# --- 1. LOAD SECRETS FROM USB (if present) ---
[ -f "/boot/secrets.txt" ] && source /boot/secrets.txt

# --- 2. SYSTEM SECURITY & WAKE-ON-LAN ---
echo "root:${DIETPI_PASSWORD:-dietpi}" | chpasswd
apt-get update && apt-get install -y ethtool openvpn sqlite3
printf 'auto eth0\niface eth0 inet dhcp\n    ethernet-wol g\n' > /etc/network/interfaces.d/eth0
ethtool -s eth0 wol g

# --- 3. EXPRESSVPN OPENVPN SETUP ---
mkdir -p /etc/openvpn
printf '%s\n%s\n' "${EXPRESSVPN_USER}" "${EXPRESSVPN_PASS}" > /etc/openvpn/pass.txt
chmod 600 /etc/openvpn/pass.txt
wget -q -O /etc/openvpn/expressvpn.conf "https://raw.githubusercontent.com/ajdhoward/nas-config/master/my_expressvpn_switzerland_udp.ovpn"
sed -i 's|^auth-user-pass$|auth-user-pass /etc/openvpn/pass.txt|' /etc/openvpn/expressvpn.conf
systemctl enable openvpn@expressvpn 2>/dev/null || true

# --- 4. INSTALL DIETPI SOFTWARE ---
dietpi-software install 130 137 134 135 146 162 96

# --- 5. PRE-CONFIGURE REVERSE PROXY BASE URLs ---
sqlite3 /var/lib/sonarr/sonarr.db "UPDATE Config SET Value='/sonarr' WHERE Key='UrlBase';" 2>/dev/null || true
sqlite3 /var/lib/radarr/radarr.db "UPDATE Config SET Value='/radarr' WHERE Key='UrlBase';" 2>/dev/null || true
sqlite3 /var/lib/prowlarr/prowlarr.db "UPDATE Config SET Value='/prowlarr' WHERE Key='UrlBase';" 2>/dev/null || true

# --- 6. QUIET-HOURS SCHEDULER FOR qBITTORRENT ---
mkdir -p /home/dietpi/.config/qBittorrent
cat > /home/dietpi/.config/qBittorrent/qBittorrent.conf << 'QBT_EOF'
[Preferences]
Scheduler\Enabled=true
Scheduler\StartHour=2
Scheduler\EndHour=7
QueueingSystem\MaxActiveDownloads=3
QBT_EOF

# --- 7. CLONE YOUR FORKS (HARDCODED URLS - NO VARIABLES) ---
git clone https://github.com/ajdhoward/AIOStreams /home/dietpi/AIOStreams
cd /home/dietpi/AIOStreams && npm ci --omit=dev

git clone https://github.com/ajdhoward/AIOMetadata /home/dietpi/AIOMetadata
cd /home/dietpi/AIOMetadata && npm ci --omit=dev

# --- 8. PROCESS MANAGEMENT WITH PM2 ---
npm install -g pm2
pm2 start /home/dietpi/AIOStreams/index.js --name "aiostreams"
pm2 start /home/dietpi/AIOMetadata/index.js --name "aiometadata"
pm2 save
pm2 startup

# --- 9. MOUNT STORAGE & CONFIGURE SAMBA ---
mkdir -p /mnt/media
mount /dev/sdb1 /mnt/media 2>/dev/null || true
(echo "${SAMBA_PASSWORD:-dietpi}"; echo "${SAMBA_PASSWORD:-dietpi}") | smbpasswd -s -a root 2>/dev/null || true

# --- 10. FINAL STATUS ---
echo "✅ NAS setup complete!"
echo "🌐 Jellyfin: http://$(hostname -I | awk '{print $1}'):8096"
echo "📺 Sonarr:  http://$(hostname -I | awk '{print $1}'):8989"
echo "🎬 Radarr:  http://$(hostname -I | awk '{print $1}'):7878"
echo "🔍 Prowlarr: http://$(hostname -I | awk '{print $1}'):9696"
echo "🔑 Torbox API key ready: ${TORBOX_API_KEY:-[NOT SET]}"
