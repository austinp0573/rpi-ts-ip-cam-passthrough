#!/bin/bash

# starts the camera bridge service

if [ "$EUID" -ne 0 ]; then 
    echo "error: must run with sudo"
    exit 1
fi

if [ ! -f /etc/systemd/system/camera-bridge.service ]; then
    echo "error: service not installed, run sudo ./setup.sh first"
    exit 1
fi

echo "starting camera bridge..."

if systemctl is-active --quiet camera-bridge; then
    echo "already running, restarting..."
    systemctl restart camera-bridge
else
    systemctl start camera-bridge
fi

sleep 2

if systemctl is-active --quiet camera-bridge; then
    echo "camera bridge started"
    echo ""
    systemctl status camera-bridge --no-pager -l
else
    echo "failed to start, showing logs:"
    echo ""
    journalctl -u camera-bridge -n 20 --no-pager
    exit 1
fi