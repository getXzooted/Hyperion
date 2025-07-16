#!/bin/bash
# Component: kubernetes-dashboard
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "  -> Deploying Kubernetes Dashboard..."
kubectl apply -k /opt/Hyperion/kubernetes/apps/kubernetes-dashboard/

echo "  -> Waiting for Kubernetes Dashboard to become ready..."
kubectl wait --for=condition=available -n kubernetes-dashboard deployment/kubernetes-dashboard --timeout=180s

echo "  -> Kubernetes Dashboard component installed successfully."