# ==========================================
# Stage 1: Build liboqs and strongSwan
# ==========================================
FROM debian:trixie-slim AS builder

ARG STRONGSWAN_VERSION=6.1.0
ARG LIBOQS_VERSION=0.16.0

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    ninja-build \
    libssl-dev \
    curl \
    bzip2 \
    ca-certificates \
    pkg-config

# 1. Build and install liboqs 0.16.0 (FIPS 203 ML-KEM)
WORKDIR /tmp/liboqs
RUN curl -sSL https://github.com/open-quantum-safe/liboqs/archive/refs/tags/${LIBOQS_VERSION}.tar.gz | tar -xz --strip-components=1 \
    && mkdir build && cd build \
    && cmake -GNinja \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=ON \
        -DOQS_USE_OPENSSL=ON \
        -DOQS_BUILD_ONLY_LIB=ON .. \
    && ninja install

# 2. Build strongSwan 6.1.0 with OQS & modern swanctl/VICI
WORKDIR /tmp/strongswan
RUN curl -sSL https://download.strongswan.org/strongswan-${STRONGSWAN_VERSION}.tar.bz2 | tar -xj --strip-components=1 \
    && ./configure \
        --prefix=/usr \
        --sysconfdir=/etc \
        --enable-silent-rules \
        --enable-swanctl \
        --enable-vici \
        --enable-oqs \
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
    && make install DESTDIR=/install

# ==========================================
# Stage 2: Clean Runtime Image (Zero Devtools)
# ==========================================
FROM debian:trixie-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    iproute2 \
    iptables \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Copy liboqs shared libraries from builder
COPY --from=builder /usr/lib/liboqs.so* /usr/lib/

# Copy installed strongSwan binaries and plugins from staged DESTDIR
COPY --from=builder /install/usr /usr
COPY --from=builder /install/etc /etc

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 500/udp 4500/udp

ENTRYPOINT ["/entrypoint.sh"]