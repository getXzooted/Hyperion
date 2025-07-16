#!/bin/bash
set -e
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo "  -> Deploying Grafana..."
kubectl apply -f /opt/Hyperion/kubernetes/apps/grafana/
kubectl wait --for=condition=available -n grafana deployment/grafana --timeout=180s