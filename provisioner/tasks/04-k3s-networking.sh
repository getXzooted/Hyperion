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
kubectl apply --server-side -f /opt/Hyperion/kubernetes/manifests/system/calico/tigera-operator.yaml

echo "  -> Waiting for Calico Operator Deployment to become available..."
kubectl wait --for=condition=available -n tigera-operator deployment/tigera-operator --timeout=300s

echo "  -> Calico Operator is ready. Waiting for Calico API to be established..."
# This is the correct, intelligent wait. It waits for the API to be ready for our specific kind of resource.
kubectl wait --for condition=established crd/installations.operator.tigera.io --timeout=300s

echo "  -> Calico API is ready. Applying Calico custom resource configuration..."
# Now that the API is ready, we can apply our configuration.
kubectl apply --server-side  --force-conflicts -f /opt/Hyperion/kubernetes/manifests/system/calico/custom-resources.yaml
echo "  -> Calico Installation resource applied successfully."

echo "  -> Waiting for cluster nodes to become Ready as Calico initializes..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

echo "  -> Deploying MetalLB Controller..."
# We use kubectl apply on the whole metallb.yaml first to install the controller
kubectl apply -f /opt/Hyperion/kubernetes/manifests/system/metallb/metallb.yaml

echo "  -> Waiting for MetalLB controller to become ready..."
# We must wait for the controller to be available before applying its configuration
kubectl wait --for=condition=available -n metallb-system deployment/controller --timeout=300s

echo "  -> Configuring MetalLB IPAddressPool..."
# Now that the controller is ready, we can apply the IPAddressPool configuration
IP_RANGE=$(jq -r '.parameters.metallb_ip_range' "$CONFIG_FILE")
if [ -z "$IP_RANGE" ] || [ "$IP_RANGE" = "null" ]; then
  echo "  -> ERROR: Could not find 'metallb_ip_range' in config file: $CONFIG_FILE"
  echo "     Please ensure the key exists under 'parameters' and has a value."
  exit 1
fi
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