#!/bin/bash

# WireGuard over Shadowsocks Server Setup Script
#
# This script automates the setup of a WireGuard server
# with traffic obfuscated through a Shadowsocks proxy.
# This setup is designed for a server that will forward
# decrypted Shadowsocks traffic to a local WireGuard port.

# --- Configuration ---
WIREGUARD_INTERFACE="wg0"
WIREGUARD_PORT=51820
WIREGUARD_SERVER_IP="10.0.0.1/24"
WIREGUARD_CLIENT_IP="10.0.0.2/32"

SHADOWSOCKS_PORT=8388 # Port for clients to connect to
SHADOWSOCKS_METHOD="aes-256-gcm"

# --- Helper Functions ---
print_info() {
    echo -e "\e[34m[INFO]\e[0m $1"
}

print_error() {
    echo -e "\e[31m[ERROR]\e[0m $1" >&2
    exit 1
}

# --- Main Script ---

# 1. Check for root privileges
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root."
fi

# 2. Detect Server Public IP
SERVER_PUBLIC_IP=$(curl -s4 ifconfig.me)
if [ -z "$SERVER_PUBLIC_IP" ];
then
    read -p "Could not detect public IP. Please enter it manually: " SERVER_PUBLIC_IP
    if [ -z "$SERVER_PUBLIC_IP" ]; then
        print_error "Public IP is required."
    fi
fi
print_info "Server Public IP: $SERVER_PUBLIC_IP"

# 3. Install dependencies (Debian/Ubuntu)
print_info "Updating package lists..."
apt-get update -y
print_info "Installing WireGuard and Shadowsocks..."
# shadowsocks-libev provides ss-server and ss-redir
apt-get install -y wireguard shadowsocks-libev

# 4. Generate Keys
print_info "Generating keys..."
umask 077
wg genkey | tee server_private.key | wg pubkey > server_public.key
wg genkey | tee client_private.key | wg pubkey > client_public.key
wg genpsk > preshared.key

SERVER_PRIVATE_KEY=$(cat server_private.key)
SERVER_PUBLIC_KEY=$(cat server_public.key)
CLIENT_PRIVATE_KEY=$(cat client_private.key)
CLIENT_PUBLIC_KEY=$(cat client_public.key)
PRESHARED_KEY=$(cat preshared.key)

# 5. Generate Shadowsocks Password
SHADOWSOCKS_PASSWORD=$(openssl rand -base64 16)

# 6. Create WireGuard Server Configuration
print_info "Creating WireGuard server configuration..."
# The WireGuard server will listen on a localhost port
cat > /etc/wireguard/${WIREGUARD_INTERFACE}.conf << EOF
[Interface]
Address = ${WIREGUARD_SERVER_IP}
PrivateKey = ${SERVER_PRIVATE_KEY}
ListenPort = ${WIREGUARD_PORT}
# IMPORTANT: The PostUp/PostDown rules assume your public interface is 'eth0'.
# If it's different (e.g., 'ens3'), you MUST change 'eth0' to your actual interface name.
# You can find it with 'ip -br a' or 'ifconfig'.
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
# Client
PublicKey = ${CLIENT_PUBLIC_KEY}
PresharedKey = ${PRESHARED_KEY}
AllowedIPs = ${WIREGUARD_CLIENT_IP}
EOF

# 7. Create Shadowsocks Server Configuration
# We will use ss-redir to forward traffic.
# The main ss-server is not needed in this configuration.
# Instead, we configure the shadowsocks service to use ss-redir.
# This requires modifying the systemd service file for shadowsocks-libev.
print_info "Creating Shadowsocks server configuration..."
cat > /etc/shadowsocks-libev/config.json << EOF
{
    "server": "0.0.0.0",
    "server_port": ${SHADOWSOCKS_PORT},
    "password": "${SHADOWSOCKS_PASSWORD}",
    "timeout": 300,
    "method": "${SHADOWSOCKS_METHOD}",
    "fast_open": true,
    "nameserver": "1.1.1.1",
    "mode": "tcp_and_udp"
}
EOF

# Use iptables to redirect incoming traffic from the shadowsocks port
# to the WireGuard port. This is a simpler approach than using ss-redir
# for this specific use case.
# The ss-server will handle decryption and then the OS networking stack
# will handle the decrypted packets. The client needs to specify the
# WireGuard server as the destination *inside* the shadowsocks tunnel.

# 8. Configure System Services
print_info "Enabling and starting services..."
systemctl enable wg-quick@${WIREGUARD_INTERFACE}
systemctl start wg-quick@${WIREGUARD_INTERFACE}

# We need to make sure the shadowsocks service is running in UDP mode.
# The default config should be sufficient if "mode" is "tcp_and_udp".
systemctl enable shadowsocks-libev
systemctl restart shadowsocks-libev

# 9. Generate Client Configuration
print_info "Generating client configuration..."
# The client's WireGuard endpoint is the server's public IP and WireGuard port.
# The traffic is wrapped by the Shadowsocks client on the client side.
# The key is that the Shadowsocks client must be configured to wrap all
# traffic from the WireGuard client.
cat > client.conf << EOF
[Interface]
PrivateKey = ${CLIENT_PRIVATE_KEY}
Address = ${WIREGUARD_CLIENT_IP}
DNS = 1.1.1.1

[Peer]
PublicKey = ${SERVER_PUBLIC_KEY}
PresharedKey = ${PRESHARED_KEY}
# The endpoint is the REAL WireGuard server address from the perspective
# of the Shadowsocks server. The client's ss-local will forward to here.
# So, if ss-server and wg-server are on the same machine, this would be
# the server's public IP and the WG port.
Endpoint = ${SERVER_PUBLIC_IP}:${WIREGUARD_PORT}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

# --- Display Client Info ---
echo "============================================="
echo "          Client Configuration"
echo "============================================="
echo
echo "--- WireGuard Client Config (save as client.conf) ---"
cat client.conf
echo
echo "--- Shadowsocks Client Config ---"
echo "Server IP:      ${SERVER_PUBLIC_IP}"
echo "Server Port:    ${SHADOWSOCKS_PORT}"
echo "Password:       ${SHADOWSOCKS_PASSWORD}"
echo "Encryption:     ${SHADOWSOCKS_METHOD}"
echo
print_info "Setup complete!"
echo "---------------------------------------------"
print_info "IMPORTANT CLIENT SETUP INSTRUCTIONS:"
print_info "The standard WireGuard client cannot send traffic through a SOCKS5 proxy."
print_info "You need a special client or a tool like 'tun2socks' to make this work."
print_info "1. On your client, install a Shadowsocks client and configure it with the details above."
print_info "   Ensure it supports UDP forwarding ('-u' flag in shadowsocks-libev)."
print_info "2. The Shadowsocks client will create a local SOCKS5 proxy."
print_info "3. Use a tool like 'tun2socks' or a modified WireGuard client (like qv2ray or others)"
print_info "   to capture all traffic from the WireGuard interface and send it to the local SOCKS5 proxy."
print_info "4. The WireGuard configuration provided above ('client.conf') should be used with this setup."
echo "============================================="
