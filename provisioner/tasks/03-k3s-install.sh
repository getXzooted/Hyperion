#!/bin/bash
# Task: 03-k3s-install.sh 
# Installs a pinned K3s version and disables kube-proxy for Calico compatibility.

set -e

#New block to disable flannel to allow our calico to take over
echo "  -> Creating K3s configuration file to ensure correct startup..."
mkdir -p /etc/rancher/k3s

INSTALL_K3S_VERSION="v1.28.9+k3s1"
echo "  -> Installing K3s v${INSTALL_K3S_VERSION} with flags for Calico..."
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