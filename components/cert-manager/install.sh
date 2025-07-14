#!/bin/bash
# Component: cert-manager
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "  -> Deploying Cert-Manager..."
kubectl apply -f /opt/Hyperion/kubernetes/base/cert-manager/cert-manager.yaml

echo "  -> Waiting for Cert-Manager webhook to become ready..."
kubectl wait --for=condition=available -n cert-manager deployment/cert-manager-webhook --timeout=180s

echo "  -> Cert-Manager component installed successfully."