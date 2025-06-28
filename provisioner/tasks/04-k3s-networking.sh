#!/bin/bash
# Task: 04-k3s-networking.sh
# Deploys CNI, Load Balancer, and Ingress Controller.

set -e

# This script receives the path to the config file as its first argument
CONFIG_FILE="$1"
if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
    echo "  -> ERROR: Config file not provided or not found!"
    exit 1
fi

# Set KUBECONFIG so kubectl commands work
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "  -> Waiting for K3s API server to be available..."
until kubectl get nodes >/dev/null 2>&1; do
    echo "  -> K3s not ready yet, waiting 5 seconds..."
    sleep 5
done

echo "  -> Deploying Calico CNI using Server-Side Apply..."
# Server-side apply is more robust and avoids issues with large annotations on CRDs.
# We must specify a field-manager name, which can be our script's name.
kubectl apply --server-side --field-manager=hyperion-provisioner -f /opt/Hyperion/kubernetes/manifests/system/calico/tigera-operator.yaml
echo "  -> Waiting for Calico operator to become ready..."
echo "  -> Waiting 15 seconds for the calico-system namespace to be created..."
sleep 15
# Now, we wait for the operator deployment to be available. This resolves the race condition.
kubectl wait --for=condition=available -n calico-system deployment/tigera-operator --timeout=300s
echo "  -> Calico operator is ready. Applying custom resources..."
# Now that the operator is ready, we can safely apply its custom resources.
kubectl apply --server-side --field-manager=hyperion-provisioner -f /opt/Hyperion/kubernetes/manifests/system/calico/custom-resources.yaml

echo "  -> Waiting for nodes to be Ready (this may take a few minutes)..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

echo "  -> Deploying MetalLB (Load Balancer)..."
kubectl apply -f /opt/Hyperion/kubernetes/manifests/system/metallb/metallb.yaml
# Wait for MetalLB pods to be ready before configuring them
kubectl wait --for=condition=available -n metallb-system deployments --all --timeout=300s

echo "  -> Configuring MetalLB IP Address Pool..."
# Read the IP range from our config.json file
IP_RANGE=$(jq -r '.parameters.metallb_ip_range' "$CONFIG_FILE")

# Create the MetalLB configuration using a heredoc
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