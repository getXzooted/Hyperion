#!/bin/bash
# Component: ingress-nginx


set -e


export KUBECONFIG=/etc/rancher/k3s/k3s.yaml


echo "  ---------> Deploying Nginx Ingress Controller <---------  "
kubectl apply -f /opt/Hyperion/kubernetes/base/ingress-nginx/deploy.yaml

echo "  ---------> Waiting for Nginx Ingress Controller to become ready <---------  "
kubectl wait --for=condition=available -n ingress-nginx deployment/ingress-nginx-controller --timeout=300s

echo "  ---------> Ingress-Nginx component installed successfully. <---------  "