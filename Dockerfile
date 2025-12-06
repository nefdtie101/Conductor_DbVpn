FROM ubuntu:22.04

LABEL authors="johannnefdr"
LABEL description="WireGuard VPN + socat TCP Proxy for PostgreSQL"

ENV DEBIAN_FRONTEND=noninteractive

# Install required packages - using socat instead of nginx for simpler TCP proxying
RUN apt-get update && \
    apt-get install -y \
    wireguard \
    wireguard-tools \
    iptables \
    iproute2 \
    socat \
    postgresql-client \
    openresolv \
    curl \
    net-tools \
    dnsutils \
    iputils-ping \
    bind9-host \
    && rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p /etc/wireguard

# Copy startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# PostgreSQL proxy port
EXPOSE 5432

CMD ["/start.sh"]
