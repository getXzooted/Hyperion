#!/bin/bash
# Task: 08-network-policies.sh
# Applies all base network policies for the platform.


set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "  ---------> Waiting for Calico NetworkPolicy CRDs to be established <---------  "
kubectl wait --for condition=established crd/networkpolicies.projectcalico.org --timeout=120s

echo "  ---------> Forcing API reconciliation by listing Calico CRDs <---------  "
kubectl get crds | grep calico || true
sleep 5

echo "  ---------> Applying Base Network Policies <---------  "
kubectl apply --server-side --force-conflicts -f /opt/Hyperion/kubernetes/manifests/system/policies/*.yaml

echo "  ---------> Base Network Policies Complete <---------  "