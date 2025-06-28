#!/bin/bash
# Task: 04-k3s-networking.sh
# Deploys CNI, Load Balancer, and Ingress with all discovered race condition fixes.
set -e

CONFIG_FILE="$1"
if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
    echo "  -> ERROR: Config file not provided or not found!"
    exit 1
fi

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Use a simple but effective readiness check. We just need to know the API server is up.
echo "  -> Waiting for K3s API server to be available..."
TIMEOUT=120
SECONDS=0
while ! kubectl get nodes >/dev/null 2>&1; do
  if [ $SECONDS -ge $TIMEOUT ]; then
    echo "  -> ERROR: Timed out waiting for K3s API server to become available."
    exit 1
  fi
  echo "  -> K3s API server not ready yet. Waiting 5 more seconds..."
  sleep 5
  SECONDS=$((SECONDS + 5))
done
echo "  -> K3s API server is ready."

echo "  -> Deploying Calico CNI using Server-Side Apply..."
kubectl apply --server-side --field-manager=hyperion-provisioner -f /opt/Hyperion/kubernetes/manifests/system/calico/tigera-operator.yaml

echo "  -> Waiting for the calico-system namespace to be created..."
TIMEOUT=120
SECONDS=0
while ! kubectl get namespace calico-system >/dev/null 2>&1; do
  if [ $SECONDS -ge $TIMEOUT ]; then
    echo "  -> ERROR: Timed out waiting for 'calico-system' namespace."; exit 1
  fi
  sleep 5
done
echo "  -> Namespace 'calico-system' found."

echo "  -> Waiting for Calico operator to become ready..."
kubectl wait --for=condition=available -n calico-system deployment/tigera-operator --timeout=300s

echo "  -> Calico operator is ready. Applying custom resources..."
kubectl apply --server-side --field-manager=hyperion-provisioner -f /opt/Hyperion/kubernetes/manifests/system/calico/custom-resources.yaml

echo "  -> Deploying MetalLB (Load Balancer)..."
kubectl apply -f /opt/Hyperion/kubernetes/manifests/system/metallb/metallb.yaml
kubectl wait --for=condition=available -n metallb-system deployments --all --timeout=300s

echo "  -> Configuring MetalLB IP Address Pool..."
IP_RANGE=$(jq -r '.parameters.metallb_ip_range' "$CONFIG_FILE")
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: primary-pool
  namespace: metallb-system
spec:
  addresses:
  - ${IP_RANGE}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default-advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - primary-pool
EOF

echo "  -> Deploying Nginx Ingress Controller..."
kubectl apply -f /opt/Hyperion/kubernetes/manifests/system/nginx/deploy.yaml

echo "  -> k3s Networking Tasks Complete."