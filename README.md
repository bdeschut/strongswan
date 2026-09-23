# RPI OS Prep

```bash
# Prepare config
sudo mkdir /opt/strongswan
sudo chmod 0700 /opt/strongswan
sudo vi /opt/strongswan/strongswan.conf # See example config file in this repo (strongswan.conf)
sudo chmod 0600 /opt/strongswan/strongswan.conf
sudo vi /etc/containers/systemd/ipsec.container # See example systemd file
sudo podman pull ghcr.io/bdeschut/pq-strongswan:latest

# Optional, if you want containers to auto update
sudo systemctl enable --now podman-auto-update.timer

# sudo modprobe af_key xfrm_user xfrm_algo esp4 # First one didn't seem loaded on "clean" system
# = not needed

sudo sysctl -w net.ipv4.ip_forward=1

sudo systemctl daemon-reload
sudo systemctl start ipsec
# For now, until next rebuild:
podman exec -it ipsec-vpn apt-get install -y --no-install-recommends iputils-ping

# Not sure about this one:
iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
```

# Troubleshooting
```bash
podman exec -it ipsec-vpn ip xfrm state
podman exec -it ipsec-vpn ip xfrm policy
ip xfrm policy
podman exec -it ipsec-vpn swanctl --load-all
podman exec -it ipsec-vpn swanctl --initiate --child paloalto-tunnel
```

```bash
# Terminate any established SA
podman exec -it ipsec-vpn swanctl --terminate --ike paloalto-hub

# Verify SA table is completely empty
podman exec -it ipsec-vpn swanctl --list-sas

# Send a ping to the Palo Alto tunnel IP to trigger the trap
ping -c 3 changeme_HUB_VPN_IP
```

# Building the container(s) (multi-arch support via [[REBUILD.md](REBUILD.md)])

# Test

```bash
# optional, if you need to move the build container from local user to root:
podman save localhost/pq-strongswan:latest | sudo podman load

# Terminal 1: container running charon
podman run --rm -it --name ipsec-spoke --net=host --cap-add=NET_ADMIN,NET_RAW localhost/pq-strongswan:latest
# OR when pulling from github:
podman run --rm -it --name ipsec-spoke --net=host --cap-add=NET_ADMIN,NET_RAW gcr.io/bdeschut/pq-strongswan:latest

# Terminal 2: talk to the running charon via VICI
podman exec -it ipsec-spoke swanctl --list-algs
podman exec -it ipsec-spoke swanctl --list-conns
podman exec -it ipsec-spoke swanctl --initiate --child ...
```

# Pushing to ghcr

See [[REBUILD.md](REBUILD.md)] for multi-arch build and push procedure.
