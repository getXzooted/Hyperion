#!/bin/bash
# Task: 03-k3s-install.sh (v1.1 - Pinned Version)
# Installs a specific, known-stable version of K3s to ensure compatibility.
set -e

# Define a specific stable version to avoid latest-version bugs
INSTALL_K3S_VERSION="v1.28.9+k3s1"

echo "  -> Starting K3s installation for pinned version ${INSTALL_K3S_VERSION}..."
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${INSTALL_K3S_VERSION} INSTALL_K3S_EXEC=" \
    --flannel-backend=none \
    --disable-network-policy \
    --disable=traefik \
    --disable=servicelb \
    --write-kubeconfig-mode=644" sh -

echo "  -> K3s installed. Waiting for server to be ready..."
sleep 30

# This SUDO_USER variable is set by the 'sudo' command.
if [ -n "$SUDO_USER" ]; then
    chown "$SUDO_USER":"$SUDO_USER" /etc/rancher/k3s/k3s.yaml
fi

echo "  -> k3s Installation Complete."