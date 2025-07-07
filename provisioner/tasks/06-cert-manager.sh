#!/bin/bash
# Task: 06-cert-manager.sh
# Deploys cert-manager for automated TLS certificates.


set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "  ---------> Deploying Cert-Manager <---------  "
kubectl apply --server-side --force-conflicts -f /opt/Hyperion/kubernetes/manifests/system/cert-manager/cert-manager.yaml

echo "  ---------> Waiting for Cert-Manager to become ready <---------  "
kubectl wait --for=condition=available -n cert-manager deployment/cert-manager-webhook --timeout=180s

echo "  ---------> Cert-Manager Deployment Complete. <---------  "