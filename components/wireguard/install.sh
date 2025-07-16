#!/bin/bash
set -e
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "  -> Deploying WireGuard Server..."
kubectl apply -f /opt/Hyperion/kubernetes/apps/wireguard/

echo "  -> Waiting for WireGuard to become ready..."
kubectl wait --for=condition=available -n wireguard deployment/wireguard --timeout=180s

echo "  -> WireGuard component installed successfully."