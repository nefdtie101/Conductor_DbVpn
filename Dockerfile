FROM ubuntu:22.04

LABEL authors="johannnefdr"
LABEL description="WireGuard VPN + Nginx Reverse Proxy for PostgreSQL"

ENV DEBIAN_FRONTEND=noninteractive

# Install required packages from official Nginx repo
RUN apt-get update && \
    apt-get install -y curl gnupg2 ca-certificates lsb-release && \
    echo "deb http://nginx.org/packages/ubuntu $(lsb_release -cs) nginx" \
      | tee /etc/apt/sources.list.d/nginx.list && \
    curl -fsSL https://nginx.org/keys/nginx_signing.key | apt-key add - && \
    apt-get update && \
    apt-get install -y nginx \
    wireguard \
    wireguard-tools \
    iptables \
    iproute2 \
    postgresql-client \
    gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p /etc/wireguard /var/log/nginx /run

# Copy startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh


# PostgreSQL proxy and Health check (WireGuard client doesn't expose ports)
EXPOSE 5432 8080

CMD ["/start.sh"]
