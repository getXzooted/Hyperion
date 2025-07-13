#!/bin/bash
# Task: 04-calico.sh
# Deploys the Calico CNI and waits for nodes to become available


set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "  ---------> Waiting for K3s API server to be available <---------  "
TIMEOUT=120
SECONDS=0
while ! kubectl get nodes >/dev/null 2>&1; do
  if [ $SECONDS -ge $TIMEOUT ]; then
    echo "  ---------> ERROR: Timed out waiting for K3s API server to become available. <---------  "
    exit 1
  fi
  echo "  ---------> K3s API server not ready yet. Waiting 5 more seconds <---------  "
  sleep 5
  SECONDS=$((SECONDS + 5))
done

echo "  ---------> K3s API server is ready. <---------  "

echo "  ---------> Deploying Calico CNI <---------  "
kubectl apply --server-side -f /opt/Hyperion/kubernetes/base/calico-system/tigera-operator.yaml

#echo "  ---------> Patching Calico Operator with initialDelaySeconds and tolerations <---------  "
#kubectl patch deployment -n tigera-operator tigera-operator --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/readinessProbe/initialDelaySeconds", "value": 15}]'

echo "  ---------> Waiting for Calico Operator Deployment to become available <---------  "
kubectl wait --for=condition=available -n tigera-operator deployment/tigera-operator --timeout=300s

echo "  ---------> Calico Operator is ready. Waiting for Calico API to be established <---------  "
kubectl wait --for condition=established crd/installations.operator.tigera.io --timeout=300s

echo "  ---------> Calico API is ready. Applying Calico custom resource configuration <---------  "
kubectl apply --server-side  --force-conflicts -f /opt/Hyperion/kubernetes/base/calico-system/custom-resources.yaml

echo "  ---------> Waiting for cluster nodes to become Ready as Calico initializes <---------  "
kubectl wait --for=condition=Ready nodes --all --timeout=300s

echo "  ---------> Waiting for cluster pods to become Ready as Calico initializes <---------  "
kubectl wait --for=condition=Ready pods -n calico-system --all --timeout=300s

echo "  ---------> Calico Installation resource applied successfully. <---------  "