#!/bin/bash

# helper script to update config.yaml
# honestly just editing the yaml directly might be easier

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_FILE="${SCRIPT_DIR}/config.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "error: config.yaml not found"
    echo "copy config.yaml.example to config.yaml first"
    exit 1
fi

echo "configure camera bridge"
echo ""
echo "which network?"
echo "  1) home"
echo "  2) deployment"
read -p "choice: " network_choice

case $network_choice in
    1) NETWORK="home" ;;
    2) NETWORK="deployment" ;;
    *)
        echo "invalid choice"
        exit 1
        ;;
esac

echo ""
read -p "camera ip: " CAMERA_IP
read -p "username: " CAMERA_USER
read -sp "password: " CAMERA_PASS
echo ""
read -p "rtsp port [554]: " RTSP_PORT
RTSP_PORT=${RTSP_PORT:-554}
read -p "main stream path [/ch0]: " RTSP_MAIN
RTSP_MAIN=${RTSP_MAIN:-/ch0}
read -p "sub stream path [/ch1]: " RTSP_SUB
RTSP_SUB=${RTSP_SUB:-/ch1}
read -p "onvif port [80]: " ONVIF_PORT
ONVIF_PORT=${ONVIF_PORT:-80}
read -p "http port [80]: " HTTP_PORT
HTTP_PORT=${HTTP_PORT:-80}
read -p "https port [0]: " HTTPS_PORT
HTTPS_PORT=${HTTPS_PORT:-0}

echo ""
echo "updating config..."

python3 << EOF
import yaml

with open('${CONFIG_FILE}', 'r') as f:
    config = yaml.safe_load(f)

config['${NETWORK}']['camera_ip'] = '${CAMERA_IP}'
config['${NETWORK}']['camera_username'] = '${CAMERA_USER}'
config['${NETWORK}']['camera_password'] = '${CAMERA_PASS}'
config['${NETWORK}']['rtsp_main_stream'] = '${RTSP_MAIN}'
config['${NETWORK}']['rtsp_sub_stream'] = '${RTSP_SUB}'
config['${NETWORK}']['rtsp_port'] = ${RTSP_PORT}
config['${NETWORK}']['onvif_port'] = ${ONVIF_PORT}
config['${NETWORK}']['http_port'] = ${HTTP_PORT}
config['${NETWORK}']['https_port'] = ${HTTPS_PORT}

with open('${CONFIG_FILE}', 'w') as f:
    yaml.dump(config, f, default_flow_style=False, sort_keys=False)
EOF

echo "saved"
echo ""

read -p "set as active network? (y/n): " SET_ACTIVE
if [[ $SET_ACTIVE =~ ^[Yy]$ ]]; then
    python3 << EOF
import yaml
with open('${CONFIG_FILE}', 'r') as f:
    config = yaml.safe_load(f)
config['active_network'] = '${NETWORK}'
with open('${CONFIG_FILE}', 'w') as f:
    yaml.dump(config, f, default_flow_style=False, sort_keys=False)
EOF
    echo "${NETWORK} is now active"
fi
