#!/bin/bash

# tests camera connectivity and shows connection urls

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_FILE="${SCRIPT_DIR}/config.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "error: config.yaml not found"
    exit 1
fi

get_config() {
    python3 << EOF
import yaml
with open('${CONFIG_FILE}', 'r') as f:
    config = yaml.safe_load(f)
keys = '$1'.split('.')
value = config
for k in keys:
    value = value[k]
print(value)
EOF
}

echo "testing camera bridge"
echo ""

ACTIVE_NETWORK=$(get_config "active_network")
echo "active network: $ACTIVE_NETWORK"

CAMERA_IP=$(get_config "${ACTIVE_NETWORK}.camera_ip")
CAMERA_USER=$(get_config "${ACTIVE_NETWORK}.camera_username")
CAMERA_PASS=$(get_config "${ACTIVE_NETWORK}.camera_password")
RTSP_PORT=$(get_config "${ACTIVE_NETWORK}.rtsp_port")
RTSP_MAIN=$(get_config "${ACTIVE_NETWORK}.rtsp_main_stream")
RTSP_SUB=$(get_config "${ACTIVE_NETWORK}.rtsp_sub_stream")
ONVIF_PORT=$(get_config "${ACTIVE_NETWORK}.onvif_port")
HTTP_PORT=$(get_config "${ACTIVE_NETWORK}.http_port")

FORWARD_RTSP_MAIN=$(get_config "forwarded_ports.rtsp_main")
FORWARD_RTSP_SUB=$(get_config "forwarded_ports.rtsp_sub")
FORWARD_ONVIF=$(get_config "forwarded_ports.onvif")
FORWARD_HTTP=$(get_config "forwarded_ports.http")

echo "camera ip: $CAMERA_IP"
echo ""

# test camera reachability
echo "pinging camera..."
if ping -c 5 -W 3 $CAMERA_IP > /dev/null 2>&1; then
    echo "  ok"
else
    echo "  failed - camera unreachable"
    echo "  check ip and network connection"
    exit 1
fi

# test camera ports
echo ""
echo "testing camera ports..."
test_port() {
    if timeout 3 bash -c "cat < /dev/null > /dev/tcp/$1/$2" 2>/dev/null; then
        echo "  $3 (port $2): ok"
        return 0
    else
        echo "  $3 (port $2): failed"
        return 1
    fi
}

test_port $CAMERA_IP $RTSP_PORT "rtsp"
test_port $CAMERA_IP $ONVIF_PORT "onvif"
test_port $CAMERA_IP $HTTP_PORT "http"

# check if bridge is running
echo ""
echo "checking bridge service..."
if systemctl is-active --quiet camera-bridge 2>/dev/null; then
    echo "  running"
else
    echo "  not running"
    echo "  run: sudo ./start.sh"
fi

# check forwarded ports
echo ""
echo "checking forwarded ports..."
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo "local ip: $LOCAL_IP"

if command -v tailscale &> /dev/null; then
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "")
    [ -n "$TAILSCALE_IP" ] && echo "tailscale ip: $TAILSCALE_IP"
fi

test_port localhost $FORWARD_RTSP_MAIN "rtsp main"
test_port localhost $FORWARD_RTSP_SUB "rtsp sub"
test_port localhost $FORWARD_ONVIF "onvif"
test_port localhost $FORWARD_HTTP "http"

# show connection info
if [ -n "$TAILSCALE_IP" ]; then
    echo ""
    echo "connection urls (use in tinycam):"
    echo ""
    echo "main stream:"
    echo "  rtsp://$CAMERA_USER:$CAMERA_PASS@$TAILSCALE_IP:$FORWARD_RTSP_MAIN$RTSP_MAIN"
    echo ""
    echo "sub stream:"
    echo "  rtsp://$CAMERA_USER:$CAMERA_PASS@$TAILSCALE_IP:$FORWARD_RTSP_SUB$RTSP_SUB"
    echo ""
    echo "onvif (for ptz):"
    echo "  host: $TAILSCALE_IP"
    echo "  port: $FORWARD_ONVIF"
    echo "  user: $CAMERA_USER"
    echo "  pass: $CAMERA_PASS"
    echo ""
    echo "web interface:"
    echo "  http://$TAILSCALE_IP:$FORWARD_HTTP"
fi

echo ""
echo "test complete"