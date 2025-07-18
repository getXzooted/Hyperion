#!/bin/bash
# Component: ingress-nginx


set -e


export KUBECONFIG=/etc/rancher/k3s/k3s.yaml


# --- Read User's Private Config ---
USER_CONFIG_FILE="/etc/hyperion/config/config-$(hostname).json"
DOMAIN_NAME=$(jq -r '.parameters.domain_name' "$USER_CONFIG_FILE")
CERT_EMAIL=$(jq -r '.parameters.cert_manager_email' "$USER_CONFIG_FILE")

if [ -z "$DOMAIN_NAME" ] || [ -z "$CERT_EMAIL" ]; then
  echo "  ---------> ERROR: 'domain_name' or 'cert_manager_email' not found in $USER_CONFIG_FILE <---------  "
  exit 1
fi


echo "  ---------> Deploying Nginx Ingress Controller <---------  "
kubectl apply -f /opt/Hyperion/kubernetes/base/ingress-nginx/deploy.yaml

echo "  ---------> Waiting for Nginx Ingress Controller to become ready <---------  "
kubectl wait --for=condition=available -n ingress-nginx deployment/ingress-nginx-controller --timeout=300s

echo "  ---------> Ingress-Nginx component installed successfully. <---------  "


echo "  ---------> Auto-generating ClusterIssuer for domain: ${DOMAIN_NAME} <---------  "
# --- Auto-generate the ClusterIssuer manifest ---
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

echo "  ---------> Ingress-Nginx component and ClusterIssuer created successfully. <---------  "