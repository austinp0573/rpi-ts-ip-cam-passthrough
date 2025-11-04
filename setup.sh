#!/bin/bash

# installs dependencies and sets up the camera bridge service
# run this once when setting up a new pi

set -e

if [ "$EUID" -ne 0 ]; then 
    echo "error: must run with sudo"
    echo "usage: sudo ./setup.sh"
    exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "working directory: $SCRIPT_DIR"
echo ""

# update system
echo "updating system packages..."
apt update
apt upgrade -y
echo ""

# install socat
echo "installing socat..."
if command -v socat &> /dev/null; then
    echo "already installed"
else
    apt install -y socat
    echo "installed"
fi
echo ""

# install python and yaml support
echo "installing python yaml support..."
apt install -y python3 python3-yaml
echo ""

# install tailscale
echo "installing tailscale..."
if command -v tailscale &> /dev/null; then
    echo "already installed"
    tailscale --version
else
    curl -fsSL https://tailscale.com/install.sh | sh
    echo "installed"
fi
echo ""

# enable ip forwarding
echo "enabling ip forwarding..."
if grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "already enabled"
else
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -p
    echo "enabled"
fi
echo ""

# create systemd service
echo "creating systemd service..."
ACTUAL_USER="${SUDO_USER:-$USER}"
echo "service will run as: $ACTUAL_USER"

cat > /etc/systemd/system/camera-bridge.service << EOF
[Unit]
Description=Camera Bridge Service
After=network-online.target tailscaled.service
Wants=network-online.target
Requires=tailscaled.service

[Service]
Type=simple
User=${ACTUAL_USER}
WorkingDirectory=${SCRIPT_DIR}
ExecStart=${SCRIPT_DIR}/bridge.sh
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
echo "service created"
echo ""

# check tailscale auth
echo "checking tailscale..."
if tailscale status &> /dev/null; then
    echo "already authenticated"
    TAILSCALE_IP=$(tailscale ip -4)
    echo "tailscale ip: $TAILSCALE_IP"
else
    echo "needs authentication"
    echo "copy the url below and open in a browser:"
    echo ""
    tailscale up
fi
echo ""

echo "setup complete"
echo ""
echo "next steps:"
echo "  1. copy config.yaml.example to config.yaml"
echo "  2. edit config.yaml with your camera details"
echo "  3. run: sudo ./start.sh"
echo "  4. run: ./test-connection.sh"
