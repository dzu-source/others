# WireGuard over Shadowsocks

This project provides a set of scripts and configurations to easily set up a WireGuard VPN tunnel obfuscated by a Shadowsocks proxy. This is useful for bypassing network restrictions and deep packet inspection (DPI) that might block standard VPN protocols.

## How it works

The setup involves two main components:

1.  **Server**: A Linux server running both WireGuard and Shadowsocks (`ss-server`). The WireGuard traffic is sent over the Shadowsocks tunnel.
2.  **Client**: A client machine that uses a Shadowsocks client to wrap all WireGuard traffic.

This way, the WireGuard traffic is wrapped inside the Shadowsocks tunnel, making it difficult to detect and block.

## Features

- Automated server setup script for Debian-based systems.
- Generates all necessary keys and configuration files.
- Secure by default with pre-shared keys.
- Detailed client setup guide.

## Installation

1.  **Server Setup**
    - Clone this repository onto your server.
    - Run the setup script as root: `sudo bash server_setup.sh`.
    - The script will install all dependencies and generate the necessary configurations.
    - At the end, it will display the client configuration details. Securely copy these to your client machine.

2.  **Client Setup**
    - Please follow the detailed **[Client Setup Guide](./client_setup.md)** to configure your client. Due to the nature of this setup, the client configuration is more involved than a standard VPN.

## Disclaimer

This project is for educational purposes only. Use it at your own risk. Ensure you are complying with the laws and regulations of your country. The use of a hardcoded network interface name (`eth0`) in the server script might require manual changes if your server uses a different name.
