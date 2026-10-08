# RPI OS Prep

```bash
# Prepare config
sudo mkdir /opt/strongswan
sudo chmod 0700 /opt/strongswan
sudo vi /opt/strongswan/strongswan.conf # See example config file in this repo (strongswan.conf)
sudo chmod 0600 /opt/strongswan/strongswan.conf
sudo vi /opt/strongswan/swanctl.conf # See example config file in this repo (swanctl.conf)
sudo chmod 0600 /opt/strongswan/swanctl.conf
sudo vi /etc/containers/systemd/ipsec.container # See example systemd file
sudo vi /etc/systemd/system/ipsec-interface.service # See example systemd file
sudo podman pull ghcr.io/bdeschut/pq-strongswan:latest

sudo sysctl -w net.ipv4.ip_forward=1

sudo systemctl daemon-reload
# Optional, if you want containers to auto update
sudo systemctl enable --now podman-auto-update.timer
sudo systemctl enable --now ipsec-interface.service
sudo systemctl start ipsec

# Not sure about this one:
# iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
```

# Troubleshooting
```bash
# Check healthcheck status:
podman inspect --format '{{.State.Health.Status}} (FailingStreak: {{.State.Health.FailingStreak}})' ipsec-vpn
```

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

# Post Quantum crypto

The Two Types of Post-Quantum IPsec:

| Feature |	Type 1: Post-Quantum Pre-Shared Key (PPK) |	Type 2: Post-Quantum Key Exchange (PQ KEM) |
| --- | --- |  --- | 
| Standard	| RFC 8784 (What you are using) |	RFC 9370 / RFC 9242 |
| How it works |	Uses standard classical DH (like ecp384), then injects a static out-of-band secret (PPK) into the symmetric Key Derivation Function (SKEYSEED).	| Swaps or supplements DH over the wire with lattice algorithms (e.g., ML-KEM-768 / Kyber). |
| Required library |	Standard OpenSSL (kdf plugin). Built into strongSwan core. |	liboqs (via strongSwan oqs plugin). |
| Palo Alto PAN-OS Support	| Full Support (PAN-OS "Post-Quantum" checkbox).	| Not Supported by PAN-OS. |

## Why Your Setup Worked Without liboqs: ##

When PAN-OS asks for "Post-Quantum = Required", it strictly demands an RFC 8784 PPK.
Because symmetric encryption (AES-256) and hashing (SHA-384) are already quantum-resistant (Grover’s algorithm only cuts symmetric key space by half, leaving 256-bit keys with 128 bits of true post-quantum security), RFC 8784 neutralizes the "harvest now, decrypt later" threat using standard symmetric math.
StrongSwan has supported RFC 8784 natively in its core code since version 5.8.3. It does not touch liboqs for this.
