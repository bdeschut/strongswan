# Image Rebuild & Release Guide

Step-by-step instructions to rebuild and publish multi-architecture container images (`linux/amd64` and `linux/arm64`) using Podman and GitHub Container Registry (`ghcr.io`).

---

## Rebuild Triggers & Pre-Requisites

Common reasons to rebuild:
- **New strongSwan version**: Update `STRONGSWAN_VERSION` and `VERSION` in the variable block.
- **Modified build flags or plugins**: Update the `./configure` options in [Dockerfile](file:///opt/strongswan/Dockerfile), commit and push the changes, then pull them on both build hosts.
- **Base image or script updates**: Update packages in [Dockerfile](file:///opt/strongswan/Dockerfile) or logic in [entrypoint.sh](file:///opt/strongswan/entrypoint.sh), commit and push, then pull on both build hosts.

### Registry Authentication (Required on both build hosts)
Before pushing, ensure Podman is logged in to GHCR with a GitHub Personal Access Token (PAT) having `write:packages` scope:
```bash
echo "${CR_PAT}" | podman login ghcr.io -u <GITHUB_USERNAME> --password-stdin
```

---

## Step 1: System 1 (x86_64 / amd64 Host) — Build & Push amd64 Image

Execute these commands in order on the x86_64 / amd64 build host:

```bash
# Define variables
REGISTRY="ghcr.io/bdeschut"
IMAGE_NAME="pq-strongswan"
STRONGSWAN_VERSION="6.1.0"
VERSION="${STRONGSWAN_VERSION}_$(date +%Y%m%d)"
ARCH=$(podman info --format '{{.Host.Arch}}')

# 1. Pull latest repository changes
git pull

# 2. Build local image
podman build \
    --build-arg STRONGSWAN_VERSION="${STRONGSWAN_VERSION}" \
    -t "${IMAGE_NAME}:latest" \
    -t "${IMAGE_NAME}:${VERSION}" \
    -f Dockerfile .

# 3. Tag image with architecture suffix
podman tag "${IMAGE_NAME}:${VERSION}" "${REGISTRY}/${IMAGE_NAME}:${VERSION}-${ARCH}"

# 4. Push architecture-specific image to GHCR
podman push "${REGISTRY}/${IMAGE_NAME}:${VERSION}-${ARCH}"
```

---

## Step 2: System 2 (ARM64 / Raspberry Pi Host) — Build & Push arm64 Image

Execute these commands in order on the ARM64 / Raspberry Pi build host:

```bash
# Define variables (ensure STRONGSWAN_VERSION and VERSION match Step 1)
REGISTRY="ghcr.io/bdeschut"
IMAGE_NAME="pq-strongswan"
STRONGSWAN_VERSION="6.1.0"
VERSION="${STRONGSWAN_VERSION}_$(date +%Y%m%d)"
ARCH=$(podman info --format '{{.Host.Arch}}')

# 1. Pull latest repository changes
git pull

# 2. Build local image
podman build \
    --build-arg STRONGSWAN_VERSION="${STRONGSWAN_VERSION}" \
    -t "${IMAGE_NAME}:latest" \
    -t "${IMAGE_NAME}:${VERSION}" \
    -f Dockerfile .

# 3. Tag image with architecture suffix
podman tag "${IMAGE_NAME}:${VERSION}" "${REGISTRY}/${IMAGE_NAME}:${VERSION}-${ARCH}"

# 4. Push architecture-specific image to GHCR
podman push "${REGISTRY}/${IMAGE_NAME}:${VERSION}-${ARCH}"
```

---

## Step 3: Manifest Host (System 1, System 2, or Workstation) — Assemble & Push Multi-Arch Manifests

Execute these commands in order on any machine authenticated to GHCR (System 1, System 2, or your workstation):

```bash
# Define variables
REGISTRY="ghcr.io/bdeschut"
IMAGE_NAME="pq-strongswan"
STRONGSWAN_VERSION="6.1.0"
VERSION="${STRONGSWAN_VERSION}_$(date +%Y%m%d)"
LATEST_TAG="latest"
ARCH_AMD64="amd64"
ARCH_ARM64="arm64"

# 1. Create and push versioned manifest list (${VERSION})
podman rmi "${REGISTRY}/${IMAGE_NAME}:${VERSION}" 2>/dev/null || true
podman manifest create "${REGISTRY}/${IMAGE_NAME}:${VERSION}"

for ARCH in "${ARCH_AMD64}" "${ARCH_ARM64}"; do
    podman manifest add "${REGISTRY}/${IMAGE_NAME}:${VERSION}" "docker://${REGISTRY}/${IMAGE_NAME}:${VERSION}-${ARCH}"
done

podman manifest push "${REGISTRY}/${IMAGE_NAME}:${VERSION}"

# 2. Create and push 'latest' manifest list (${LATEST_TAG})
podman rmi "${REGISTRY}/${IMAGE_NAME}:${LATEST_TAG}" 2>/dev/null || true
podman manifest create "${REGISTRY}/${IMAGE_NAME}:${LATEST_TAG}"

for ARCH in "${ARCH_AMD64}" "${ARCH_ARM64}"; do
    podman manifest add "${REGISTRY}/${IMAGE_NAME}:${LATEST_TAG}" "docker://${REGISTRY}/${IMAGE_NAME}:${VERSION}-${ARCH}"
done

podman manifest push "${REGISTRY}/${IMAGE_NAME}:${LATEST_TAG}"
```

---

## Step 4: Target System(s) — Verification & Deployment

### 1. Verify Manifest on Registry (Run on any host)

Confirm both architectures are present in the remote manifest index:

```bash
REGISTRY="ghcr.io/bdeschut"
IMAGE_NAME="pq-strongswan"
STRONGSWAN_VERSION="6.1.0"
VERSION="${STRONGSWAN_VERSION}_$(date +%Y%m%d)"

podman manifest inspect "${REGISTRY}/${IMAGE_NAME}:${VERSION}"
```

### 2. Pull and Test Architecture (Run on each target machine)

Verify that the local machine downloads its matching native architecture:

```bash
REGISTRY="ghcr.io/bdeschut"
IMAGE_NAME="pq-strongswan"
STRONGSWAN_VERSION="6.1.0"
VERSION="${STRONGSWAN_VERSION}_$(date +%Y%m%d)"

podman pull "${REGISTRY}/${IMAGE_NAME}:${VERSION}"
Or just:
podman pull ghcr.io/bdeschut/pq-strongswan:latest
podman image inspect "${REGISTRY}/${IMAGE_NAME}:${VERSION}" --format 'Architecture: {{.Architecture}}'
```

### 3. Deploy Container Update (Run on production host, e.g. Raspberry Pi)

Trigger automatic container update or restart the systemd service:

```bash
sudo podman auto-update
```
