#!/bin/bash
# Component: wireguard


set -e


export KUBECONFIG=/etc/rancher/k3s/k3s.yaml


echo "  -> Deploying WireGuard..."
# We use -k to apply the entire directory via its kustomization.
kubectl apply -k /opt/Hyperion/kubernetes/apps/wireguard/

echo "  -> Waiting for WireGuard to become ready..."
kubectl wait --for=condition=available -n wireguard deployment/wireguard --timeout=300s

echo "  -> WireGuard component installed successfully."