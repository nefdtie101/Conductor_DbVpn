FROM ubuntu:22.04

LABEL authors="johannnefdr"
LABEL description="WireGuard VPN + Nginx Reverse Proxy for PostgreSQL"

ENV DEBIAN_FRONTEND=noninteractive

# Install required packages from Ubuntu repositories
RUN apt-get update && \
    apt-get install -y \
    nginx \
    wireguard \
    wireguard-tools \
    iptables \
    iproute2 \
    postgresql-client \
    gettext-base \
    openresolv \
    curl \
    gnupg2 \
    ca-certificates \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p /etc/wireguard /var/log/nginx /run

# Copy startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# PostgreSQL proxy and Health check (WireGuard client doesn't expose ports)
EXPOSE 5432 8080

CMD ["/start.sh"]
