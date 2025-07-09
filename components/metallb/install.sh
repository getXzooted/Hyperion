#!/bin/bash
# Task: 05-metallb.sh
# Deploys the MetalLB load balancer.


set -e

CONFIG_FILE="/etc/hyperion/config/config-$(hostname).json"
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "  ---------> Deploying MetalLB Controller <---------  "
kubectl apply -f /opt/Hyperion/kubernetes/manifests/system/metallb/metallb.yaml

echo "  ---------> Waiting for MetalLB controller to become ready <---------  "
kubectl wait --for=condition=available -n metallb-system deployment/controller --timeout=300s

echo "  ---------> Configuring MetalLB IPAddressPool <---------  "
IP_RANGE=$(jq -r '.parameters.metallb_ip_range' "/etc/hyperion/config/config-$(hostname).json")
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

echo "  ---------> MetalLB Installation resource applied successfully. <---------  "