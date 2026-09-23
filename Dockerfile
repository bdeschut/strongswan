# ==========================================
# Stage 1: Build liboqs and strongSwan
# ==========================================
FROM debian:trixie-slim AS builder

ARG STRONGSWAN_VERSION=6.1.0
ARG LIBOQS_VERSION=0.16.0
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    ninja-build \
    libssl-dev \
    curl \
    bzip2 \
    ca-certificates \
    pkg-config

# 1. Build liboqs with OQS_DIST_BUILD=ON (portable across Pi 4 and Pi 5)
WORKDIR /tmp/liboqs
RUN curl -sSL https://github.com/open-quantum-safe/liboqs/archive/refs/tags/${LIBOQS_VERSION}.tar.gz | tar -xz --strip-components=1 \
    && mkdir build && cd build \
    && cmake -GNinja \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=ON \
        -DOQS_DIST_BUILD=ON \
        -DOQS_USE_OPENSSL=ON \
        -DOQS_BUILD_ONLY_LIB=ON .. \
    && ninja install \
    && DESTDIR=/install ninja install

# 2. Build strongSwan with OQS & install into /install staging tree
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
    # --- PRUNE UNNEEDED HEADERS AND STRIP SYMBOLS ---
    # && rm -rf /install/usr/include /install/usr/share/man /install/usr/share/doc \
    # && find /install/usr -type f \( -name "*.so*" -o -perm /111 \) -exec strip --strip-unneeded {} + 2>/dev/null || true
# ==========================================
# Stage 2: Clean Runtime Image (Zero Devtools)
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

# Copy everything staged (both liboqs and strongSwan) cleanly
COPY --from=builder /install/usr /usr
COPY --from=builder /install/etc /etc

# Update the dynamic linker cache
RUN ldconfig

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 500/udp 4500/udp

ENTRYPOINT ["/entrypoint.sh"]
