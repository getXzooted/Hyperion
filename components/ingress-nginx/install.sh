#!/bin/bash
# Component: ingress-nginx


set -e


export KUBECONFIG=/etc/rancher/k3s/k3s.yaml


echo "  ---------> Deploying Nginx Ingress Controller <---------  "
kubectl apply -f /opt/Hyperion/kubernetes/base/ingress-nginx/deploy.yaml

echo "  ---------> Waiting for Nginx Ingress Controller to become ready <---------  "
kubectl wait --for=condition=available -n ingress-nginx deployment/ingress-nginx-controller --timeout=300s

echo "  -> Waiting for Ingress admission controller jobs to complete..."
kubectl wait --for=condition=complete -n ingress-nginx job/ingress-nginx-admission-create --timeout=180s
kubectl wait --for=condition=complete -n ingress-nginx job/ingress-nginx-admission-patch --timeout=180s

echo "  ---------> Ingress-Nginx component installed successfully. <---------  "