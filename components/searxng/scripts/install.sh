#!/bin/bash
# Component: searxng

set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "  -> Deploying SearXNG..."
kubectl apply -k /opt/Hyperion/kubernetes/apps/searxng/

echo "  -> Waiting for SearXNG to become ready..."
kubectl wait --for=condition=available -n searxng deployment/searxng --timeout=300s