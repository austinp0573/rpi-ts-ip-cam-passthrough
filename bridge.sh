#!/bin/bash

# main bridge script - forwards camera ports through socat

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_FILE="${SCRIPT_DIR}/config.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "error: config.yaml not found"
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo "error: python3 not installed"
    exit 1
fi

# reads a value from config.yaml
get_config() {
    local key=$1
    python3 << EOF
import yaml
with open('${CONFIG_FILE}', 'r') as f:
    config = yaml.safe_load(f)
keys = '${key}'.split('.')
value = config
for k in keys:
    value = value[k]
print(value)
EOF
}

echo "loading config..."
ACTIVE_NETWORK=$(get_config "active_network")
echo "active network: $ACTIVE_NETWORK"

# get camera settings
CAMERA_IP=$(get_config "${ACTIVE_NETWORK}.camera_ip")
CAMERA_USER=$(get_config "${ACTIVE_NETWORK}.camera_username")
CAMERA_PASS=$(get_config "${ACTIVE_NETWORK}.camera_password")
RTSP_PORT=$(get_config "${ACTIVE_NETWORK}.rtsp_port")
RTSP_MAIN=$(get_config "${ACTIVE_NETWORK}.rtsp_main_stream")
RTSP_SUB=$(get_config "${ACTIVE_NETWORK}.rtsp_sub_stream")
ONVIF_PORT=$(get_config "${ACTIVE_NETWORK}.onvif_port")
HTTP_PORT=$(get_config "${ACTIVE_NETWORK}.http_port")
HTTPS_PORT=$(get_config "${ACTIVE_NETWORK}.https_port")

# get forwarded ports
FORWARD_RTSP_MAIN=$(get_config "forwarded_ports.rtsp_main")
FORWARD_RTSP_SUB=$(get_config "forwarded_ports.rtsp_sub")
FORWARD_ONVIF=$(get_config "forwarded_ports.onvif")
FORWARD_HTTP=$(get_config "forwarded_ports.http")
FORWARD_HTTPS=$(get_config "forwarded_ports.https")

echo "camera: $CAMERA_IP"
echo "forwarding:"
echo "  rtsp: $RTSP_PORT -> $FORWARD_RTSP_MAIN, $FORWARD_RTSP_SUB"
echo "  onvif: $ONVIF_PORT -> $FORWARD_ONVIF"
echo "  http: $HTTP_PORT -> $FORWARD_HTTP"
[ "$HTTPS_PORT" != "0" ] && echo "  https: $HTTPS_PORT -> $FORWARD_HTTPS"
echo ""

declare -a SOCAT_PIDS

# cleanup handler for when script exits
cleanup() {
    echo "stopping socat processes..."
    for pid in "${SOCAT_PIDS[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    echo "stopped"
    exit 0
}

trap cleanup SIGTERM SIGINT

# starts a port forward
start_forward() {
    local desc=$1
    local local_port=$2
    local remote_ip=$3
    local remote_port=$4
    
    echo "starting: $desc ($local_port -> $remote_ip:$remote_port)"
    
    socat -d -d \
        TCP-LISTEN:$local_port,reuseaddr,fork \
        TCP:$remote_ip:$remote_port \
        2>&1 | while read line; do
            echo "[port $local_port] $line"
        done &
    
    SOCAT_PIDS+=($!)
    sleep 0.5
    
    if kill -0 ${SOCAT_PIDS[-1]} 2>/dev/null; then
        echo "  running (pid: ${SOCAT_PIDS[-1]})"
    else
        echo "  failed to start"
    fi
}

# start forwards
start_forward "rtsp main" $FORWARD_RTSP_MAIN $CAMERA_IP $RTSP_PORT
start_forward "rtsp sub" $FORWARD_RTSP_SUB $CAMERA_IP $RTSP_PORT
start_forward "onvif" $FORWARD_ONVIF $CAMERA_IP $ONVIF_PORT
start_forward "http" $FORWARD_HTTP $CAMERA_IP $HTTP_PORT
[ "$HTTPS_PORT" != "0" ] && start_forward "https" $FORWARD_HTTPS $CAMERA_IP $HTTPS_PORT

echo ""
echo "bridge running"

# show connection info if tailscale is available
if command -v tailscale &> /dev/null; then
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "")
    if [ -n "$TAILSCALE_IP" ]; then
        echo "tailscale ip: $TAILSCALE_IP"
        echo ""
        echo "rtsp urls:"
        echo "  main: rtsp://$CAMERA_USER:$CAMERA_PASS@$TAILSCALE_IP:$FORWARD_RTSP_MAIN$RTSP_MAIN"
        echo "  sub:  rtsp://$CAMERA_USER:$CAMERA_PASS@$TAILSCALE_IP:$FORWARD_RTSP_SUB$RTSP_SUB"
        echo ""
        echo "onvif: http://$TAILSCALE_IP:$FORWARD_ONVIF"
        echo "web:   http://$TAILSCALE_IP:$FORWARD_HTTP"
        echo ""
    fi
fi

echo "press ctrl+c to stop"
echo ""

# monitoring loop
while true; do
    for i in "${!SOCAT_PIDS[@]}"; do
        pid="${SOCAT_PIDS[$i]}"
        if ! kill -0 "$pid" 2>/dev/null; then
            echo "warning: process $pid died"
        fi
    done
    sleep 30
done
