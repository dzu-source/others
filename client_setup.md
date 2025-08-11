# Client Setup Guide: WireGuard over Shadowsocks

This guide explains how to configure your client machine to connect to the WireGuard server through a Shadowsocks proxy. This setup is necessary to obfuscate your WireGuard traffic.

## 1. How It Works

Standard WireGuard clients cannot send their traffic through a SOCKS5 proxy directly. Therefore, we need an intermediary tool to capture the encrypted WireGuard packets and forward them to our local Shadowsocks client. The data flow looks like this:

`WireGuard Client -> tun2socks -> Shadowsocks Client -> Internet -> Your Server`

## 2. Required Software

You will need to install three components on your client machine:

1.  **WireGuard Client**: The standard WireGuard client for your operating system.
2.  **Shadowsocks Client**: A client that supports UDP forwarding (e.g., `shadowsocks-libev` on Linux, or other clients on different platforms).
3.  **tun2socks Tool**: A tool that creates a virtual network interface (TUN) and forwards all traffic from it to a SOCKS5 proxy. A popular choice is `badvpn-tun2socks`.

## 3. Configuration Details from Server

After running the `server_setup.sh` script on your server, you will have the following pieces of information. You need to securely transfer them to your client machine.

-   **`client.conf`**: The WireGuard configuration file.
-   **Shadowsocks Server Details**:
    -   Server IP
    -   Server Port
    -   Password
    -   Encryption Method

## 4. Generic Setup Steps (Example for Linux)

These steps show the general process. You will need to adapt them to your specific OS and client software.

### Step 1: Install Software (on Debian/Ubuntu)

```bash
sudo apt-get update
sudo apt-get install -y wireguard shadowsocks-libev badvpn-tun2socks
```

### Step 2: Configure and Run Shadowsocks Client

Create a `shadowsocks-client.json` file with the details from your server:

```json
{
    "server":"YOUR_SERVER_IP",
    "server_port":8388,
    "local_address": "127.0.0.1",
    "local_port":1080,
    "password":"YOUR_SHADOWSOCKS_PASSWORD",
    "method":"aes-256-gcm",
    "mode":"tcp_and_udp",
    "fast_open":true
}
```

Now, run the Shadowsocks client in the background:

```bash
ss-local -c shadowsocks-client.json -u &
```

This starts a SOCKS5 proxy on `127.0.0.1:1080` that supports UDP.

### Step 3: Configure `tun2socks` and WireGuard

1.  **Modify `client.conf`**:
    Open your `client.conf` file and change the `Endpoint` to a dummy IP, as `tun2socks` will be handling the routing. The port should remain the same. For example:
    ```
    # In client.conf
    [Peer]
    Endpoint = 192.0.2.1:51820 # Dummy IP, real routing is handled by tun2socks
    ```
    This is because we don't want the OS to route the packets directly. `tun2socks` will capture them from the WireGuard interface.

2.  **Create a script to bring everything up**:
    Create a script named `start_vpn.sh`:

    ```bash
    #!/bin/bash

    # 1. Start tun2socks
    badvpn-tun2socks --tundev tun0 --netif-ipaddr 10.0.1.1 --netif-netmask 255.255.255.0 \
      --socks-server-addr 127.0.0.1:1080 &

    # 2. Configure the WireGuard interface
    wg-quick up ./client.conf

    # 3. Set the route for the real server IP to go through the normal gateway,
    #    so that the Shadowsocks client can connect to it.
    #    Replace YOUR_SERVER_IP and YOUR_GATEWAY_IP accordingly.
    ip route add YOUR_SERVER_IP via YOUR_GATEWAY_IP

    echo "VPN is UP. Press Ctrl+C to stop."

    # Wait for user to press Ctrl+C
    trap "echo 'Stopping VPN...'; wg-quick down ./client.conf; killall badvpn-tun2socks; exit" INT
    wait
    ```

    You need to find your default gateway IP with `ip route | grep default`.

### Step 4: Connect

Run the script: `sudo ./start_vpn.sh`. All your traffic should now be routed through the WireGuard over Shadowsocks tunnel.

## 5. Platform-Specific Clients

The manual setup on Linux is complex. For other platforms (and even for Linux), you might prefer to use a client that has this functionality built-in. These clients handle the `tun2socks` part for you.

-   **Windows / macOS / Linux**:
    -   **Qv2ray**: A powerful, cross-platform client that supports various proxy protocols. You can import your Shadowsocks configuration and then configure it to tunnel WireGuard traffic.
    -   **NekoRay / NekoBox**: Another excellent cross-platform client with advanced routing capabilities.

When using these clients, you typically:
1.  Add your Shadowsocks server.
2.  Create a WireGuard profile using your `client.conf` details.
3.  Set up routing rules to direct WireGuard traffic through the Shadowsocks proxy.

This is often much simpler than the manual `tun2socks` setup. Please refer to the documentation of your chosen client for specific instructions.
