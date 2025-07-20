#!/bin/bash
# Component: metallb
# Script: configs.sh


set -e


echo "  ---------> Configuring MetalLB IPAddressPool <---------  "
USER_CONFIG_FILE="/etc/hyperion/config/config-$(hostname).json"
IP_RANGE=$(jq -r '.parameters.metallb_ip_range' "$USER_CONFIG_FILE")

if [ -z "$IP_RANGE" ] || [ "$IP_RANGE" = "null" ]; then
  echo "  -> ERROR: 'metallb_ip_range' not found in your config file."
  exit 1
fi

echo "  -> Applying custom configuration for MetalLB..."

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

echo "  -> MetalLB IPAddressPool configured successfully."