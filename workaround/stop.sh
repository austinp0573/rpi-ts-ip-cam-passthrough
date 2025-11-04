#!/bin/bash

# stops mediamtx service

if [ "$EUID" -ne 0 ]; then 
    echo "error: must run with sudo"
    exit 1
fi

if [ ! -f /etc/systemd/system/mediamtx.service ]; then
    echo "service not installed"
    exit 0
fi

echo "stopping mediamtx..."

if ! systemctl is-active --quiet mediamtx; then
    echo "not running"
    exit 0
fi

systemctl stop mediamtx
sleep 1

if ! systemctl is-active --quiet mediamtx; then
    echo "stopped"
else
    echo "failed to stop, force killing..."
    systemctl kill mediamtx
    sleep 1
    
    if ! systemctl is-active --quiet mediamtx; then
        echo "stopped"
    else
        echo "could not stop service"
        exit 1
    fi
fi

