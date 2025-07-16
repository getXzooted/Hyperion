#!/bin/bash
set -e
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo "  -> Deploying Loki..."
kubectl apply -f /opt/Hyperion/kubernetes/apps/loki/
kubectl wait --for=condition=available -n loki deployment/loki --timeout=300s