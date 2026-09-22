# Multi-Architecture Image Build & Release Guide (Podman + GHCR)

This guide documents the workflow to build, tag, and publish multi-architecture container images (`linux/amd64` and `linux/arm64`) across separate physical machines (e.g., an x86 server and a Raspberry Pi) to GitHub Container Registry (`ghcr.io`).

---

# 1. Overview of the Strategy

1. **Build locally** on each respective machine (x86 server and Raspberry Pi).
2. **Tag & push** architecture-specific tags (`<version>-amd64` and `<version>-arm64`) to GHCR.
3. **Assemble a Manifest List** (OCI Image Index) linking both architectures under the main tags (`<version>` and `latest`).
4. **Push the Manifest List** to GHCR.

---

# Phase 1: Build & Push on Server (x86 / amd64)

Run this on your RHEL / x86 server:
```bash
# Common variables
REGISTRY="ghcr.io/bdeschut"
IMAGE_NAME="pq-strongswan"
VERSION="6.1.1-0.16.0"
ARCH=$(podman info --format '{{.Host.Arch}}')

# Make sure you are on the latest git version
git pull

# Build the image locally
podman build \
    --build-arg STRONGSWAN_VERSION=6.1.0 \
    --build-arg LIBOQS_VERSION=0.16.0 \
    -t pq-strongswan:latest \
    -t pq-strongswan:6.1.0-0.16.0 \
    -f Dockerfile .

# Tag with the architecture suffix
podman tag ${IMAGE_NAME}:latest ${REGISTRY}/${IMAGE_NAME}:${VERSION}-${ARCH}

# Push the arch-specific image to GHCR
podman push ${REGISTRY}/${IMAGE_NAME}:${VERSION}-${ARCH}
```

# Phase 2: Build & Push on Raspberry Pi (arm64)

Run this on your Raspberry Pi:
```bash
# Common variables
REGISTRY="ghcr.io/bdeschut"
IMAGE_NAME="pq-strongswan"
VERSION="6.1.1-0.16.0"
ARCH=$(podman info --format '{{.Host.Arch}}')

# Build the image locally
podman build -t ${IMAGE_NAME}:latest .

# Tag with the architecture suffix
podman tag ${IMAGE_NAME}:latest ${REGISTRY}/${IMAGE_NAME}:${VERSION}-${ARCH}

# Push the arch-specific image to GHCR
podman push ${REGISTRY}/${IMAGE_NAME}:${VERSION}-${ARCH}
```

# Phase 3: Create & Push Multi-Arch Manifests
You can run this step from either machine (or any workstation authenticated to ghcr.io).

## Versioned Tag (${VERSION})
```bash
# Remove any conflicting local tag if present
podman rmi ${REGISTRY}/${IMAGE_NAME}:${VERSION} 2>/dev/null || true

# Create the manifest list
podman manifest create ${REGISTRY}/${IMAGE_NAME}:${VERSION}

# Add both architectures from GHCR
podman manifest add ${REGISTRY}/${IMAGE_NAME}:${VERSION} docker://${REGISTRY}/${IMAGE_NAME}:${VERSION}-amd64
podman manifest add ${REGISTRY}/${IMAGE_NAME}:${VERSION} docker://${REGISTRY}/${IMAGE_NAME}:${VERSION}-arm64

# Push the manifest list to GHCR
podman manifest push ${REGISTRY}/${IMAGE_NAME}:${VERSION}
```

## Latest Tag
```bash
# Remove any conflicting local tag if present
podman rmi ${REGISTRY}/${IMAGE_NAME}:latest 2>/dev/null || true

# Create the 'latest' manifest list
podman manifest create ${REGISTRY}/${IMAGE_NAME}:latest

# Add both architectures
podman manifest add ${REGISTRY}/${IMAGE_NAME}:latest docker://${REGISTRY}/${IMAGE_NAME}:${VERSION}-amd64
podman manifest add ${REGISTRY}/${IMAGE_NAME}:latest docker://${REGISTRY}/${IMAGE_NAME}:${VERSION}-arm64

# Push the 'latest' manifest list to GHCR
podman manifest push ${REGISTRY}/${IMAGE_NAME}:latest
```

# Verification
```bash
podman manifest inspect ${REGISTRY}/${IMAGE_NAME}:${VERSION}
```
Verify that manifests contains both amd64 and arm64.

### Trigger automatic updates manually
```bash
sudo podman auto-update
```

### Manual test Pulling on each machine:
```bash
podman pull ${REGISTRY}/${IMAGE_NAME}:${VERSION}
podman image inspect ${REGISTRY}/${IMAGE_NAME}:${VERSION} --format 'Architecture: {{.Architecture}}'
```

On the x86 host, it will report Architecture: amd64. On the Raspberry Pi, it will report Architecture: arm64.
