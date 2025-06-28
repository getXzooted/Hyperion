#!/bin/bash
# Task: 03-k3s-install.sh 
# Installs a pinned K3s version and disables kube-proxy for Calico compatibility.

set -e

INSTALL_K3S_VERSION="v1.28.9+k3s1"
echo "  -> Starting K3s installation for version ${INSTALL_K3S_VERSION}..."
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${INSTALL_K3S_VERSION} INSTALL_K3S_EXEC=" \
    --flannel-backend=none \
    --disable-network-policy \
    --disable=servicelb \
    --disable=traefik \
    --disable=kube-proxy \
    --write-kubeconfig-mode=644" sh -
echo "  -> K3s installation script finished."
if [ -n "$SUDO_USER" ]; then 
    chown "$SUDO_USER":"$SUDO_USER" /etc/rancher/k3s/k3s.yaml; 
fi
echo "  -> k3s Installation Complete."