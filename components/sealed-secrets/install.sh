#!/bin/bash
set -e
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "  -> Deploying Sealed Secrets Controller..."
kubectl apply -f /opt/Hyperion/kubernetes/base/sealed-secrets/controller.yaml

echo "  -> Waiting for Sealed Secrets Controller to become ready..."
kubectl wait --for=condition=available -n kube-system deployment/sealed-secrets-controller --timeout=180s

echo "  -> Sealed Secrets component installed successfully."