#!/bin/bash
# Task: 04-k3s-networking.sh (v1.3 - Debug Enhanced)
# Deploys CNI, Load Balancer, and Ingress Controller with robust waits.
set -e

CONFIG_FILE="$1"
if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
    echo "  -> ERROR: Config file not provided or not found!"
    exit 1
fi

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "  -> Waiting for K3s API server to be available..."
until kubectl get nodes >/dev/null 2>&1; do
    echo "  -> K3s not ready yet, waiting 5 seconds..."
    sleep 5
done

# --- NEW DEBUG LOGIC SECTION ---
echo "  -> Deploying Calico CNI using Server-Side Apply..."
# We will capture all output (stdout and stderr) from the kubectl command into a variable
APPLY_OUTPUT=$(kubectl apply --server-side --force-conflicts=true --field-manager=hyperion-provisioner -f /opt/Hyperion/kubernetes/manifests/system/calico/tigera-operator.yaml 2>&1) || true

# We check if the command was successful by looking for keywords in its output
if ! echo "$APPLY_OUTPUT" | grep -q -E "created|configured|unchanged|serverside-applied"; then
  echo "  -> ERROR: Applying tigera-operator.yaml failed. Detailed output from kubectl:"
  echo "------------------- KUBECTL ERROR -------------------"
  echo "$APPLY_OUTPUT"
  echo "-----------------------------------------------------"
  exit 1
fi
echo "  -> tigera-operator.yaml applied successfully."
# --- END OF NEW DEBUG LOGIC ---

echo "  -> Waiting for the calico-system namespace to be created..."
TIMEOUT=120
SECONDS=0
while ! kubectl get namespace calico-system >/dev/null 2>&1; do
  if [ $SECONDS -ge $TIMEOUT ]; then
    echo "  -> ERROR: Timed out waiting for 'calico-system' namespace."; exit 1
  fi
  echo "  -> 'calico-system' namespace not found yet. Waiting 5 more seconds..."
  sleep 5
  SECONDS=$((SECONDS + 5))
done
echo "  -> Namespace 'calico-system' found."

echo "  -> Waiting for Calico operator to become ready..."
kubectl wait --for=condition=available -n calico-system deployment/tigera-operator --timeout=300s

echo "  -> Calico operator is ready. Applying custom resources..."
kubectl apply --server-side --force-conflicts=true --field-manager=hyperion-provisioner -f /opt/Hyperion/kubernetes/manifests/system/calico/custom-resources.yaml

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