#!/bin/bash
# Task: 03-k3s-install.sh 
# Installs a pinned K3s version and disables kube-proxy for Calico compatibility.

set -e

#New block to disable flannel to allow our calico to take over
echo "  -> Creating K3s configuration file to ensure correct startup..."
mkdir -p /etc/rancher/k3s
cat <<EOF > /etc/rancher/k3s/config.yaml
write-kubeconfig-mode: "0644"
flannel-backend: "none"
disable-network-policy: true
disable:
  - servicelb
  - traefik
  - kube-proxy
EOF

INSTALL_K3S_VERSION="v1.28.9+k3s1"
echo "  -> Starting K3s installation for version ${INSTALL_K3S_VERSION}..."
echo "  -> Installing K3s using the new config file..."
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${INSTALL_K3S_VERSION} sh -
echo "  -> K3s installation script finished."
if [ -n "$SUDO_USER" ]; then 
    chown "$SUDO_USER":"$SUDO_USER" /etc/rancher/k3s/k3s.yaml; 
fi
echo "  -> k3s Installation Complete."