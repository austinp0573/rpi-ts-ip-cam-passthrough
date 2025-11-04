#!/bin/bash

# stops the camera bridge service

if [ "$EUID" -ne 0 ]; then 
    echo "error: must run with sudo"
    exit 1
fi

if [ ! -f /etc/systemd/system/camera-bridge.service ]; then
    echo "service not installed"
    exit 0
fi

echo "stopping camera bridge..."

if ! systemctl is-active --quiet camera-bridge; then
    echo "not running"
    exit 0
fi

systemctl stop camera-bridge
sleep 1

if ! systemctl is-active --quiet camera-bridge; then
    echo "stopped"
    
    # cleanup any stray socat processes
    if pgrep -x socat > /dev/null; then
        echo "cleaning up stray socat processes..."
        pkill socat 2>/dev/null || true
    fi
else
    echo "failed to stop normally, force killing..."
    systemctl kill camera-bridge
    sleep 1
    
    if ! systemctl is-active --quiet camera-bridge; then
        echo "stopped"
    else
        echo "could not stop service, may need reboot"
        exit 1
    fi
fi