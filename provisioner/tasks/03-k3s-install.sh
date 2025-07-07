#!/bin/bash
# Task: 03-k3s-install.sh 
# Installs a pinned K3s version and disables kube-proxy for Calico compatibility.

set -e

echo "  ---------> Installing K3s v${INSTALL_K3S_VERSION} with flags for Calico <---------  "
VERSIONS_FILE="/opt/Hyperion/configs/versions.json"
INSTALL_K3S_VERSION=$(jq -r '.platform.k3s' "$VERSIONS_FILE")

echo "  ---------> Installing K3s v${INSTALL_K3S_VERSION} with flags for Calico <---------  "
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${INSTALL_K3S_VERSION} INSTALL_K3S_EXEC=" \
    --flannel-backend=none \
    --disable-network-policy \
    --disable=servicelb \
    --disable=traefik \
    --disable=kube-proxy \
    --write-kubeconfig-mode=644" sh -

echo "  ---------> K3s installation script finished. <---------  "
if [ -n "$SUDO_USER" ]; then 
    chown "$SUDO_USER":"$SUDO_USER" /etc/rancher/k3s/k3s.yaml; 
fi

echo "  ---------> k3s Installation Complete. <---------  "

echo "  ---------> Waiting for K3s API server to be available <---------  "
TIMEOUT=120
SECONDS=0
while ! kubectl get nodes >/dev/null 2>&1; do
  if [ $SECONDS -ge $TIMEOUT ]; then
    echo "  ---------> ERROR: Timed out waiting for K3s API server to become available. <---------  "
    exit 1
  fi
  echo "  ---------> K3s API server not ready yet. Waiting 5 more seconds <---------  "
  sleep 5
  SECONDS=$((SECONDS + 5))
done

echo "  ---------> K3s API server is ready. <---------  "