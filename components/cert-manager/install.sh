#!/bin/bash
# Component: cert-manager


set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "  -> Deploying Cert-Manager..."
kubectl apply -f /opt/Hyperion/kubernetes/base/cert-manager/cert-manager.yaml

echo "  -> Waiting for Cert-Manager webhook to become ready..."
kubectl wait --for=condition=available -n cert-manager deployment/cert-manager-webhook --timeout=180s

echo "  -> Cert-Manager component installed successfully."


echo "  -> Auto-generating ClusterIssuer for Let's Encrypt..."
# Read the user's private config file to get their email address
USER_CONFIG_FILE="/etc/hyperion/config/config-$(hostname).json"
CERT_EMAIL=$(jq -r '.parameters.cert_manager_email' "$USER_CONFIG_FILE")

if [ -z "$CERT_EMAIL" ] || [ "$CERT_EMAIL" = "null" ]; then
  echo "  -> ERROR: 'cert_manager_email' not found in $USER_CONFIG_FILE. Cannot create ClusterIssuer."
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