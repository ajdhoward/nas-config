#!/bin/bash
set -e
# --- EXPRESSVPN OPENVPN SETUP FOR DIETPI NAS ---
# Source credentials securely (create this file first on NAS)
# set -a; source ~/.config/acidwurx/expressvpn_creds; set +a

apt-get update && apt-get install -y openvpn

mkdir -p /etc/openvpn
# NAS will populate pass.txt from sourced env vars or manual edit
cat << 'CREDS' > /etc/openvpn/pass.txt
${EXPRESSVPN_USER}
${EXPRESSVPN_PASS}
CREDS
chmod 600 /etc/openvpn/pass.txt

# Copy .ovpn → .conf and modify auth path
SRC="/home/adam/my_expressvpn_switzerland_udp.ovpn"
DEST="/etc/openvpn/expressvpn.conf"
if [ -f "$SRC" ]; then
  cp "$SRC" "$DEST"
  sed -i 's|^auth-user-pass$|auth-user-pass /etc/openvpn/pass.txt|' "$DEST"
fi

# Disable IPv6 to prevent leaks
sysctl -w net.ipv6.conf.all.disable_ipv6=1 2>/dev/null || true
echo -e "net.ipv6.conf.all.disable_ipv6=1\nnet.ipv6.conf.default.disable_ipv6=1" >> /etc/sysctl.conf

# Enable auto-start
systemctl enable openvpn@expressvpn
systemctl start openvpn@expressvpn

# Quick verify
sleep 5
if systemctl is-active --quiet openvpn@expressvpn; then
  echo "✅ OpenVPN active"
  curl -s https://ipinfo.io/ip | xargs -I{} echo "🌐 Public IP: {}"
else
  echo "❌ OpenVPN failed - check journalctl -u openvpn@expressvpn"
  exit 1
fi
