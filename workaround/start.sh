#!/bin/bash

# starts mediamtx service

if [ "$EUID" -ne 0 ]; then 
    echo "error: must run with sudo"
    exit 1
fi

if [ ! -f /etc/systemd/system/mediamtx.service ]; then
    echo "error: service not installed, run sudo ./setup.sh first"
    exit 1
fi

echo "starting mediamtx..."

if systemctl is-active --quiet mediamtx; then
    echo "already running, restarting..."
    systemctl restart mediamtx
else
    systemctl start mediamtx
fi

sleep 2

if systemctl is-active --quiet mediamtx; then
    echo "mediamtx started"
    echo ""
    systemctl status mediamtx --no-pager -l
else
    echo "failed to start, showing logs:"
    echo ""
    journalctl -u mediamtx -n 20 --no-pager
    exit 1
fi

