#!/bin/bash
# Task: 05-metallb.sh
# Deploys the MetalLB load balancer.


set -e

CONFIG_FILE="/etc/hyperion/config/config-$(hostname).json"
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "  ---------> Deploying MetalLB Controller <---------  "
kubectl apply -f /opt/Hyperion/kubernetes/base/metallb-system/metallb.yaml

echo "  ---------> Waiting for MetalLB controller to become ready <---------  "
kubectl wait --for=condition=available -n metallb-system deployment/controller --timeout=300s

echo "  ---------> MetalLB Installation resource applied successfully. <---------  "