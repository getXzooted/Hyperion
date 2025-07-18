#!/bin/bash
# Component: perplexica


set -e


export KUBECONFIG=/etc/rancher/k3s/k3s.yaml


echo "  -> Deploying Perplexica..."
kubectl apply -k /opt/Hyperion/kubernetes/apps/perplexica/

echo "  -> Waiting for Perplexica to become ready..."
kubectl wait --for=condition=available -n perplexica deployment/perplexica --timeout=300s

echo "  -> Perplexica component installed successfully."


echo "  -> Auto-generating Ingress for Perplexica..."

# Read the user's private config file to get their domain name
USER_CONFIG_FILE="/etc/hyperion/config/config-$(hostname).json"
DOMAIN_NAME=$(jq -r '.parameters.domain_name' "$USER_CONFIG_FILE")

if [ -z "$DOMAIN_NAME" ]; then
  echo "  -> ERROR: 'domain_name' not found in $USER_CONFIG_FILE. Cannot create Ingress."
  exit 1
fi

# Dynamically generate the Ingress manifest
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: perplexica-ingress
  namespace: perplexica
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  rules:
  - host: "search.${DOMAIN_NAME}"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: perplexica-svc
            port:
              number: 80
  tls:
  - hosts:
    - "search.${DOMAIN_NAME}"
    secretName: perplexica-tls-secret
EOF

echo "  -> Ingress for Perplexica created."