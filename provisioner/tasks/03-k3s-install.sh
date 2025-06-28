#!/bin/bash
# Task: 03-k3s-install.sh
# Installs the K3s server.

set -e

echo "  -> Starting K3s installation..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC=" \
    --flannel-backend=none \
    --disable-network-policy \
    --disable=traefik \
    --disable=servicelb \
    --write-kubeconfig-mode=644" sh -

echo "  -> K3s installed. Waiting for server to be ready..."
sleep 30 # Give the server a moment to start up

# This ensures the default user can use kubectl without sudo
if [ -n "$SUDO_USER" ]; then
    chown "$SUDO_USER":"$SUDO_USER" /etc/rancher/k3s/k3s.yaml
fi

echo "  -> k3s Installation Complete."