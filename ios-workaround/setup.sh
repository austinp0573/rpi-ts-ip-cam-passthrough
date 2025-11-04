#!/bin/bash

# installs mediamtx and sets up systemd service
# run this on the pi with sudo

set -e

if [ "$EUID" -ne 0 ]; then 
    echo "error: must run with sudo"
    echo "usage: sudo ./setup.sh"
    exit 1
fi

ACTUAL_USER="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo ~$ACTUAL_USER)

echo "installing mediamtx for user: $ACTUAL_USER"
echo ""

cd "$USER_HOME"

# check if already installed
if [ -d "mediamtx" ]; then
    echo "mediamtx directory already exists"
    read -p "remove and reinstall? (y/n): " confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        systemctl stop mediamtx 2>/dev/null || true
        systemctl disable mediamtx 2>/dev/null || true
        rm -rf mediamtx mediamtx_v*.tar.gz
    else
        echo "exiting"
        exit 0
    fi
fi

# download
echo "downloading mediamtx v1.4.2..."
sudo -u $ACTUAL_USER wget https://github.com/bluenviron/mediamtx/releases/download/v1.4.2/mediamtx_v1.4.2_linux_arm64v8.tar.gz

# extract
echo "extracting..."
sudo -u $ACTUAL_USER tar -xzf mediamtx_v1.4.2_linux_arm64v8.tar.gz
sudo -u $ACTUAL_USER rm mediamtx_v1.4.2_linux_arm64v8.tar.gz

echo "installed to $USER_HOME/mediamtx"
echo ""

# create systemd service
echo "creating systemd service..."
cat > /etc/systemd/system/mediamtx.service << EOF
[Unit]
Description=MediaMTX RTSP Server
After=network.target camera-bridge.service
Wants=camera-bridge.service

[Service]
Type=simple
User=$ACTUAL_USER
WorkingDirectory=$USER_HOME/mediamtx
ExecStart=$USER_HOME/mediamtx/mediamtx
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

echo "setup complete"
echo ""
echo "next steps:"
echo "  1. edit $USER_HOME/mediamtx/mediamtx.yml"
echo "     - set 'rtsp: no' near the top"
echo "     - add camera in 'paths:' section at bottom"
echo "  2. test: cd ~/mediamtx && ./mediamtx"
echo "  3. if working, enable service:"
echo "     sudo systemctl enable mediamtx"
echo "     sudo systemctl start mediamtx"
echo ""
echo "see ios-workaround/README.md for config details"
