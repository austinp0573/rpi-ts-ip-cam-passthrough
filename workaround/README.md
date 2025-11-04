# browser-based camera viewer

tinycam monitor only exists on android. ios users need something else. this sets up mediamtx to serve the camera stream in a browser

## what it does

pulls rtsp from camera, converts to webrtc, serves at a web url. user opens safari on iphone and watches stream

downsides: no ptz controls in the player (need separate tab for that), adds about 1 second latency, uses more resources than pure forwarding

## requirements

- camera bridge already working
- ssh access to pi
- about 50mb free space on pi

## installation

### step 1: fix dns (if needed)

if you can't resolve domain names (wget fails), tailscale dns might be broken

check:
```bash
ping google.com
```

if that fails but `ping 8.8.8.8` works:

```bash
sudo tailscale set --accept-dns=false
sudo vim /etc/resolv.conf
```

replace contents with:
```
nameserver 8.8.8.8
nameserver 8.8.4.4
```

now `ping google.com` should work.

### step 1 alternative: (probably what I should have done) just download it to your workstation and use scp

---

### step 2: download mediamtx

```bash
cd ~
wget https://github.com/bluenviron/mediamtx/releases/download/v1.4.2/mediamtx_v1.4.2_linux_arm64v8.tar.gz
tar -xzf mediamtx_v1.4.2_linux_arm64v8.tar.gz
rm mediamtx_v1.4.2_linux_arm64v8.tar.gz
cd mediamtx
```

or use the setup script (also creates systemd service):
```bash
sudo ./ios-workaround/setup.sh
```

### step 3: configure mediamtx

edit config:
```bash
vim mediamtx.yml
```

find the `rtsp:` line near the top (around line 20-30) and change to:
```yaml
rtsp: no
```

this disables mediamtx's rtsp server since port 8554 is already used by the camera-bridge socat forward

scroll to bottom, find `paths:` section (around line 554), add:
```yaml
paths:
  camera:
    source: rtsp://username:password@192.168.2.50:554/ch0
    sourceProtocol: tcp
    sourceOnDemand: yes
```

important:
- use your camera's actual ip, username, password, stream path
- indent with 2 spaces (not tabs)
- `camera:` gets 2 spaces, properties get 4 spaces
- remove `runOnDemand: restart` if you added it (causes error)

save and exit

### step 4: test it

run mediamtx:
```bash
./mediamtx
```

should see:
```
INF MediaMTX v1.4.2
INF configuration loaded
INF [WebRTC] listener opened
```

if you see `bind: address already in use`, you forgot to set `rtsp: no` in the config

open browser and go to:
```
http://<tailscale-ip>:8889/camera
```

should see video player. might take a few seconds to load

press ctrl+c to stop when done testing

### step 5: make it permanent

if setup.sh already created the service, just enable and start:
```bash
sudo systemctl enable mediamtx
sudo systemctl start mediamtx
```

or use the start script:
```bash
sudo ./workaround/start.sh
```

check status:
```bash
sudo systemctl status mediamtx
```

view logs:
```bash
sudo journalctl -u mediamtx -f
```

## usage

### watching stream

user opens browser:
```
http://<tailscale-ip>:8889/camera
```

### ptz control

need to open camera web ui in separate tab:
```
http://<tailscale-ip>:8081
```

## troubleshooting

**stream won't load**

check mediamtx logs:
```bash
sudo journalctl -u mediamtx -n 50
```

common issues:
- wrong camera ip/password in mediamtx.yml
- camera not reachable from pi
- wrong stream path (/ch0 vs /stream=0 etc)

**port conflict error**

if you see `bind: address already in use`:
- make sure `rtsp: no` is set in mediamtx.yml
- restart service: `sudo systemctl restart mediamtx`

**yaml syntax error**

if mediamtx won't start with yaml error:
- check indentation (2 spaces per level, no tabs)
- `camera:` should be indented 2 spaces under `paths:`
- properties like `source:` should be 4 spaces total

**high cpu usage**

check with `top`. if mediamtx is maxing out cpu:
- use sub stream instead of main stream (lower resolution)
- change source to `/ch1` instead of `/ch0`

**out of memory**

check with `free -h`. if pi is swapping heavily, mediamtx might be too much for pi zero 2w

## commands

```bash
# start (or use sudo systemctl start mediamtx)
sudo ./workaround/start.sh

# stop (or use sudo systemctl stop mediamtx)
sudo ./workaround/stop.sh

# restart
sudo systemctl restart mediamtx

# status
sudo systemctl status mediamtx

# logs
sudo journalctl -u mediamtx -f

# disable auto-start
sudo systemctl disable mediamtx
```

## uninstall

if this doesn't work out:

```bash
sudo systemctl stop mediamtx
sudo systemctl disable mediamtx
sudo rm /etc/systemd/system/mediamtx.service
sudo systemctl daemon-reload
rm -rf ~/mediamtx ~/mediamtx_v*.tar.gz
```

camera-bridge keeps working, nothing is affected

## ports used

- 8889 - web interface (this is what users access)
- 8888 - unused (would be rtsp server but that was disabled with `rtsp: no`)
- 1985 - unused (would be rtmp but it's not being used)

## gratitude

- [mediamtx](https://github.com/bluenviron/mediamtx) - there's an open source project for all of life's problems
- Rachael - for asking me to figure out a camera setup so she could watch her cats
-- and for using an iPhone, so I could implement 2 solutions

---

&nbsp;

**466f724a616e6574**