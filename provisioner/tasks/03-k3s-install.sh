#!/bin/bash
# Task: 03-k3s-install.sh 
# Installs a pinned K3s version and disables kube-proxy for Calico compatibility.

set -e

INSTALL_K3S_VERSION=$(jq -r '.platform.k3s' /opt/Hyperion/configs/versions.json)
echo "  -> Installing K3s v${INSTALL_K3S_VERSION} with flags for Calico..."

echo "  -> Creating K3s configuration file to ensure correct startup..."
sudo mkdir -p /etc/rancher/k3s
sudo tee /etc/rancher/k3s/config.yaml > /dev/null <<EOF
# This file explicitly tells K3s to not use any CNI, preparing it for Calico.
write-kubeconfig-mode: "0644"
flannel-backend: "none"
disable-network-policy: true
disable:
  - servicelb
  - traefik
  - kube-proxy
EOF

echo "  -> Installing K3s v${INSTALL_K3S_VERSION} using the new config file..."
# The installer will automatically find and use the config.yaml file.
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${INSTALL_K3S_VERSION} sh -

echo "  -> K3s installation script finished."
if [ -n "$SUDO_USER" ]; then 
    chown "$SUDO_USER":"$SUDO_USER" /etc/rancher/k3s/k3s.yaml; 
fi

echo "  -> k3s Installation Complete."