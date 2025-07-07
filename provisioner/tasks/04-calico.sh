#!/bin/bash
# Task: 04-calico.sh
# Deploys the Calico CNI and waits for nodes to become available


set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "  ---------> Deploying Calico CNI <---------  "
kubectl apply --server-side -f /opt/Hyperion/kubernetes/manifests/system/calico/tigera-operator.yaml

echo "  ---------> Waiting for Calico Operator Deployment to become available <---------  "
kubectl wait --for=condition=available -n tigera-operator deployment/tigera-operator --timeout=300s

echo "  ---------> Calico Operator is ready. Waiting for Calico API to be established <---------  "
kubectl wait --for condition=established crd/installations.operator.tigera.io --timeout=300s

echo "  ---------> Calico API is ready. Applying Calico custom resource configuration <---------  "
kubectl apply --server-side  --force-conflicts -f /opt/Hyperion/kubernetes/manifests/system/calico/custom-resources.yaml

echo "  ---------> Waiting for cluster nodes to become Ready as Calico initializes <---------  "
kubectl wait --for=condition=Ready nodes --all --timeout=300s

echo "  ---------> Calico Installation resource applied successfully. <---------  "