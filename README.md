# OS Prep

sudo modprobe af_key xfrm_user xfrm_algo esp4

sudo sysctl -w net.ipv4.ip_forward=1

iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    ???

# Building the containers

podman build \
    --build-arg STRONGSWAN_VERSION=6.1.0 \
    --build-arg LIBOQS_VERSION=0.16.0 \
    -t pq-strongswan:latest \
    -t pq-strongswan:6.1.0-0.16.0 \
    -f Dockerfile .

podman run --rm -it localhost/pq-strongswan:latest swanctl --list-algs

## Testing

podman save localhost/pq-strongswan:latest | sudo podman load
sudo -i
podman run --rm -it --name ipsec-test --net=host --cap-add=NET_ADMIN --cap-add=NET_RAW localhost/pq-strongswan:latest

# Pushing to github private repo

    Generate new token (classic):

    - write:packages (Uploads packages to GitHub Package Registry)
    - read:packages (Downloads packages)
    - delete:packages (Optional, to prune old builds)

Login: echo "ghp_RNuk[...]]8L" | podman login ghcr.io -u bdeschut --password-stdin

# Tag the image with your GitHub registry path
podman tag pq-strongswan:latest ghcr.io/bdeschut/pq-strongswan:latest
podman tag pq-strongswan:latest ghcr.io/bdeschut/pq-strongswan:6.1.0-0.16.0

# Push both tags to GitHub
podman push ghcr.io/bdeschut/pq-strongswan:latest
podman push ghcr.io/bdeschut/pq-strongswan:6.1.0-0.16.0