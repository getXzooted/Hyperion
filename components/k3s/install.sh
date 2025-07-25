#!/bin/bash
#
# k3s
# Installs a pinned K3s version and disables kube-proxy for Calico compatibility.


set -e


if [ -f "/usr/local/bin/k3s" ]; then
    echo "  ---------> K3s is already installed. No changes needed. <---------  "
    # Exit with 0 for success, no action needed.
    exit 0
fi

echo "  ---------> Installing K3s v${INSTALL_K3S_VERSION} with flags for Calico <---------  "
VERSIONS_FILE="/opt/Hyperion/configs/versions.json"
INSTALL_K3S_VERSION=$(jq -r '.platform.k3s' "$VERSIONS_FILE")
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${INSTALL_K3S_VERSION} INSTALL_K3S_EXEC=" \
    --flannel-backend=none \
    --disable-network-policy \
    --disable=servicelb \
    --disable=traefik \
    --disable=kube-proxy \
    --write-kubeconfig-mode=644" sh -


if [ -n "$SUDO_USER" ]; then 
    chown "$SUDO_USER":"$SUDO_USER" /etc/rancher/k3s/k3s.yaml; 
fi

echo "  ---------> k3s Installation Complete. <---------  "

exit 10