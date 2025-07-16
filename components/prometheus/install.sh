#!/bin/bash
set -e
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo "  -> Deploying Prometheus..."
kubectl apply -f /opt/Hyperion/kubernetes/apps/prometheus/
kubectl wait --for=condition=available -n prometheus statefulset/prometheus-server --timeout=300s