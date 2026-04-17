#!/bin/bash
set -e

# --- 0. LOAD SECRETS FROM USB ---
[ -f "/boot/secrets.txt" ] && source /boot/secrets.txt

# --- 1. SYSTEM SECURITY & WAKE-ON-LAN ---
echo "root:${DIETPI_PASSWORD:-dietpi}" | chpasswd
apt-get update && apt-get install -y ethtool openvpn sqlite3

# Configure WoL persistently
printf 'auto eth0\niface eth0 inet dhcp\n    ethernet-wol g\n' > /etc/network/interfaces.d/eth0
ethtool -s eth0 wol g

# --- 2. AUTO-DETECT & MOUNT 3TB MEDIA DRIVE ---
# Finds drive larger than 2TB (your Seagate), gets UUID, mounts via fstab
MEDIA_DEV=$(lsblk -bndo NAME,SIZE 2>/dev/null | awk '$2 > 2000000000000 {print "/dev/"$1; exit}')
if [ -n "$MEDIA_DEV" ]; then
  MEDIA_PART="${MEDIA_DEV}1"
  if blkid "$MEDIA_PART" >/dev/null 2>&1; then
    MEDIA_UUID=$(blkid -s UUID -o value "$MEDIA_PART" 2>/dev/null || true)
    if [ -n "$MEDIA_UUID" ]; then
      mkdir -p /mnt/media
      grep -q "^UUID=$MEDIA_UUID" /etc/fstab || echo "UUID=$MEDIA_UUID /mnt/media ext4 defaults,noatime 0 2" >> /etc/fstab
      mount -a 2>/dev/null || mount "$MEDIA_PART" /mnt/media 2>/dev/null || true
      echo "✅ Mounted 3TB drive: $MEDIA_UUID"
    fi
  fi
fi

# --- 3. EXPRESSVPN OPENVPN SETUP ---
mkdir -p /etc/openvpn
printf '%s\n%s\n' "${EXPRESSVPN_USER}" "${EXPRESSVPN_PASS}" > /etc/openvpn/pass.txt
chmod 600 /etc/openvpn/pass.txt

# Download .ovpn from GitHub and configure
wget -q -O /etc/openvpn/expressvpn.conf "https://raw.githubusercontent.com/ajdhoward/nas-config/master/my_expressvpn_switzerland_udp.ovpn"
sed -i 's|^auth-user-pass$|auth-user-pass /etc/openvpn/pass.txt|' /etc/openvpn/expressvpn.conf
systemctl enable openvpn@expressvpn 2>/dev/null || true

# Disable IPv6 to prevent leaks
sysctl -w net.ipv6.conf.all.disable_ipv6=1 2>/dev/null || true
echo -e "net.ipv6.conf.all.disable_ipv6=1\nnet.ipv6.conf.default.disable_ipv6=1" >> /etc/sysctl.conf

# --- 4. INSTALL DIETPI SOFTWARE ---
# 130=Node.js | 137=Jellyfin | 134=Sonarr | 135=Radarr | 146=qBittorrent | 162=Prowlarr | 96=Samba
dietpi-software install 130 137 134 135 146 162 96

# --- 5. PRE-CONFIGURE REVERSE PROXY BASE URLs (DietPi paths) ---
sqlite3 /home/dietpi/.config/Sonarr/sonarr.db "UPDATE Config SET Value='/sonarr' WHERE Key='UrlBase';" 2>/dev/null || true
sqlite3 /home/dietpi/.config/Radarr/radarr.db "UPDATE Config SET Value='/radarr' WHERE Key='UrlBase';" 2>/dev/null || true
sqlite3 /home/dietpi/.config/Prowlarr/prowlarr.db "UPDATE Config SET Value='/prowlarr' WHERE Key='UrlBase';" 2>/dev/null || true

# --- 6. QUIET-HOURS SCHEDULER FOR qBITTORRENT ---
mkdir -p /home/dietpi/.config/qBittorrent
cat > /home/dietpi/.config/qBittorrent/qBittorrent.conf << 'QBTCONF'
[Preferences]
Scheduler\Enabled=true
Scheduler\StartHour=2
Scheduler\EndHour=7
QueueingSystem\MaxActiveDownloads=3
QBTCONF

# --- 7. CLONE YOUR FORKS (HARDCODED URLS) ---
git clone https://github.com/ajdhoward/AIOStreams /home/dietpi/AIOStreams
cd /home/dietpi/AIOStreams && npm ci --omit=dev || npm install --omit=dev

git clone https://github.com/ajdhoward/AIOMetadata /home/dietpi/AIOMetadata
cd /home/dietpi/AIOMetadata && npm ci --omit=dev || npm install --omit=dev

# --- 8. PROCESS MANAGEMENT WITH PM2 ---
npm install -g pm2
pm2 start /home/dietpi/AIOStreams/index.js --name "aiostreams"
pm2 start /home/dietpi/AIOMetadata/index.js --name "aiometadata"
pm2 save
pm2 startup

# --- 9. CONFIGURE SAMBA ---
(echo "${SAMBA_PASSWORD:-dietpi}"; echo "${SAMBA_PASSWORD:-dietpi}") | smbpasswd -s -a root 2>/dev/null || true

# --- 10. FINAL STATUS ---
echo "✅ NAS setup complete!"
echo "🌐 Jellyfin: http://$(hostname -I | awk '{print $1}'):8096"
echo "📺 Sonarr:  http://$(hostname -I | awk '{print $1}'):8989"
echo "🎬 Radarr:  http://$(hostname -I | awk '{print $1}'):7878"
echo "🔍 Prowlarr: http://$(hostname -I | awk '{print $1}'):9696"
echo "🔑 Torbox API key ready: ${TORBOX_API_KEY:-[NOT SET]}"
