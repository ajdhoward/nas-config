#!/bin/bash
# --- 1. MOUNT STORAGE ---
mkdir -p /mnt/media
mount /dev/sdb1 /mnt/media

# --- 2. CONFIGURE WAKE-ON-LAN ---
printf 'auto eth0\niface eth0 inet dhcp\n    ethernet-wol g\n' > /etc/network/interfaces.d/eth0
apt-get update && apt-get install -y ethtool
ethtool -s eth0 wol g

# --- 3. INSTALL SOFTWARE ---
dietpi-software install 130 137 134 135 146 162

# --- 4. SETUP AIOSTREAMS & METADATA ---
git clone https://github.com/ajdhoward/AIOStreams /home/dietpi/AIOStreams
cd /home/dietpi/AIOStreams && npm ci --omit=dev

git clone https://github.com/ajdhoward/AIOMetadata /home/dietpi/AIOMetadata
cd /home/dietpi/AIOMetadata && npm ci --omit=dev

# --- 5. PROCESS MANAGEMENT ---
npm install -g pm2
pm2 start /home/dietpi/AIOStreams/index.js --name "aiostreams"
pm2 start /home/dietpi/AIOMetadata/index.js --name "aiometadata"
pm2 save
pm2 startup
