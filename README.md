# tailscale camera bridge

forwards ip camera streams through a raspberry pi zero 2w via tailscale. made this because i wanted to access my thingino camera remotely without opening ports or dealing with dynamic dns.

## what it does

- runs socat on a pi to forward rtsp/onvif/http from camera
- exposes everything through tailscale
- works with tinycam monitor for viewing and ptz control

## requirements

- raspberry pi zero 2w (or any pi really)
- dietpi/raspberry pi os
- ip camera on same lan as the pi
- tailscale account (free)

## setup

### 1. install

ssh into your pi and clone this repo:

```bash
git clone <repo-url>
cd zero-ts-passthrough
```

run setup script (installs tailscale, socat, creates systemd service):

```bash
sudo ./setup.sh
```

during setup you'll get a tailscale auth url - open it in a browser and approve the device.

### 2. configure

copy the example config:

```bash
cp config.yaml.example config.yaml
```

edit config.yaml with your camera details:

```bash
nano config.yaml
```

fill in:
- camera_ip (check your router)
- camera_username (probably "admin" or "root")
- camera_password
- rtsp_main_stream (usually /ch0 or /stream=0)
- rtsp_sub_stream (usually /ch1 or /stream=1)
- onvif_port (usually 80)

or use the interactive config script:

```bash
./configure.sh
```

### 3. start

```bash
sudo ./start.sh
```

check it's working:

```bash
./test-connection.sh
```

this will show your connection urls.

## usage

### tinycam monitor setup

main stream:
```
rtsp://username:password@<tailscale-ip>:8554/ch0
```

for ptz control, enable onvif in tinycam settings:
```
host: <tailscale-ip>
port: 8080
```

### web interface

access camera web ui at:
```
http://<tailscale-ip>:8081
```

### commands

start bridge:
```bash
sudo ./start.sh
```

stop bridge:
```bash
sudo ./stop.sh
```

check status:
```bash
sudo systemctl status camera-bridge
```

view logs:
```bash
sudo journalctl -u camera-bridge -f
```

test connection:
```bash
./test-connection.sh
```

## ports

camera side:
- 554 - rtsp
- 80 - onvif/http

forwarded (tailscale):
- 8554 - rtsp main stream
- 8555 - rtsp sub stream
- 8080 - onvif
- 8081 - http admin

## deployment

to move to a different network:

1. update wifi credentials in `/etc/wpa_supplicant/wpa_supplicant.conf`
2. edit the deployment section in config.yaml
3. change active_network to "deployment"
4. restart: `sudo systemctl restart camera-bridge`

## troubleshooting

**bridge won't start:**
```bash
sudo journalctl -u camera-bridge -n 50
```

**camera unreachable:**
```bash
ping <camera-ip>
```
check camera is on same network as pi.

**tailscale issues:**
```bash
tailscale status
sudo tailscale up
```

**can't connect from phone:**
- make sure tailscale is running on phone
- check you're using the pi's tailscale ip (starts with 100.x.x.x)
- run test-connection.sh to get correct urls

## notes

- passwords stored in plain text in config.yaml (set file permissions: `chmod 600 config.yaml`)
- bridge auto-starts on boot via systemd
- works with any rtsp camera, not just thingino
- tested on pi zero 2w with dietpi but should work on any pi

## why

tried to build tailscale into thingino firmware but couldn't get it working. this was easier - just put a pi on the network and let it handle the tunneling.

## gratitude

- [thingino](https://github.com/themactep/thingino-firmware) the epic open source firmware for Ingenic SoC IP cameras
- [themactep](https://github.com/themactep) for thingino firmware
- [wltechblog](https://github.com/wltechblog) for his work on the project and the youtube content that explains it all
- All the other people who put in all the mountains of effort to get something like this working
- [Scott](https://github.com/battlehax) - for telling me about a kewl open source firmware for IP cameras

# turns out

- the end user's device is an iPhone, there is no tinyCam monitor app available for iOS, oh apple...
- the iOS [solution](https://github.com/austinp0573/rpi-ts-ip-cam-passthrough/tree/main/ios-workaround)

---

&nbsp;

**466f724a616e6574**