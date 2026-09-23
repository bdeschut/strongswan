# ==========================================
# Stage 1: Build strongSwan from Source
# ==========================================
FROM debian:trixie-slim AS builder

ARG STRONGSWAN_VERSION=6.1.0
ENV DEBIAN_FRONTEND=noninteractive

# Minimal build dependencies (cmake & ninja removed)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libssl-dev \
    curl \
    bzip2 \
    ca-certificates \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/strongswan
RUN curl -sSL https://download.strongswan.org/strongswan-${STRONGSWAN_VERSION}.tar.bz2 | tar -xj --strip-components=1 \
    && ./configure \
        --prefix=/usr \
        --sysconfdir=/etc \
        --enable-silent-rules \
        --enable-swanctl \
        --enable-vici \
        --enable-openssl \
        --enable-gcm \
        --enable-nonce \
        --enable-random \
        --enable-pem \
        --enable-pkcs1 \
        --enable-pkcs8 \
        --enable-x509 \
        --enable-cmd \
    && make -j$(nproc) \
    && make install DESTDIR=/install \
    # Prune development headers, man pages, and unneeded documentation
    && rm -rf /install/usr/include /install/usr/share/man /install/usr/share/doc \
    # Strip debugging symbols to keep the runtime binary footprint minimal
    && find /install/usr -type f \( -name "*.so*" -o -perm /111 \) -exec strip --strip-unneeded {} + 2>/dev/null || true

# ==========================================
# Stage 2: Clean Minimal Runtime Image
# ==========================================
FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    iproute2 \
    iptables \
    iputils-ping \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Copy built binaries, plugins, and configuration skeletons
COPY --from=builder /install/usr /usr
COPY --from=builder /install/etc /etc

# Refresh the dynamic linker cache for installed shared libraries
RUN ldconfig

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 500/udp 4500/udp

ENTRYPOINT ["/entrypoint.sh"]
