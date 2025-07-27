#!/bin/bash
# Component: pi-hole (Helm-aware installer)


set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "  -> Ensuring the 'pi-hole' namespace exists..."
kubectl create namespace pi-hole --dry-run=client -o yaml | kubectl apply -f -


# --- Read Configs ---
# Read our own component manifest
COMPONENT_MANIFEST="/opt/Hyperion/components/pi-hole/component.json"
HELM_REPO_URL=$(jq -r '.deployment.repository' "$COMPONENT_MANIFEST")

# Read the user's private config file
USER_CONFIG_FILE="/etc/hyperion/config/config-$(hostname).json"
ADMIN_PASSWORD=$(jq -r '.parameters.pihole_admin_password' "$USER_CONFIG_FILE")
DNS_SVC_IP=$(jq -r '.parameters.pihole_dns_ip' "$USER_CONFIG_FILE")
DOMAIN_NAME=$(jq -r '.parameters.domain_name' "$USER_CONFIG_FILE")

if [ -z "$DOMAIN_NAME" ]; then
  echo "  ---------> ERROR: 'domain_name' not found in $USER_CONFIG_FILE. Cannot create Ingress. <---------  "
  exit 1
fi

# --- Generate Flux Manifests ---
echo "  ---------> Generating HelmRelease for Pi-hole <---------  "

# 1. Create the HelmRepository object to tell Flux where to find the chart
cat <<EOF | kubectl apply -f -
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: pi-hole
  namespace: flux-system
spec:
  interval: 1h
  url: ${HELM_REPO_URL}
EOF

# 2. Create the HelmRelease object to deploy the chart with our custom values
cat <<EOF | kubectl apply -f -
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: pi-hole
  namespace: pi-hole
spec:
  interval: 5m
  chart:
    spec:
      chart: pi-hole
      version: "2.17.0" # Pinning to a specific version for stability is best practice
      sourceRef:
        kind: HelmRepository
        name: pi-hole       # This now points to the HelmRepository object
        namespace: flux-system
  # This is where we inject the user's parameters from their JSON file
  values:
    adminPassword: "${ADMIN_PASSWORD}"
    serviceDns:
      loadBalancerIP: "${DNS_SVC_IP}"
EOF

echo "  ---------> Pi-hole HelmRelease created successfully. <---------  "


echo "  ---------> Auto-generating Ingress for Pi-hole web interface <---------  "
# Dynamically generate the Ingress manifest
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: pi-hole-ingress
  namespace: pi-hole
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  rules:
  - host: "pihole.${DOMAIN_NAME}"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: pihole-web-svc
            port:
              number: 80
  tls:
  - hosts:
    - "pihole.${DOMAIN_NAME}"
    secretName: pihole-tls-secret
EOF

echo "  ---------> Ingress for Pi-hole created. <---------  "