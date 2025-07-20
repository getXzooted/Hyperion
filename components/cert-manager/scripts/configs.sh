#!/bin/bash
# Component: cert-manager
# Script: configs.sh


set -e


echo "  -> Applying custom configuration for Cert-Manager..."

# Read the user's private config file to get their email address
USER_CONFIG_FILE="/etc/hyperion/config/config-$(hostname).json"
CERT_EMAIL=$(jq -r '.parameters.cert_manager_email' "$USER_CONFIG_FILE")

if [ -z "$CERT_EMAIL" ] || [ "$CERT_EMAIL" = "null" ]; then
  echo "  -> ERROR: 'cert_manager_email' not found in your config. Cannot create ClusterIssuer."
  exit 1
fi

# Dynamically generate the ClusterIssuer manifest
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${CERT_EMAIL}
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

echo "  -> ClusterIssuer created successfully."