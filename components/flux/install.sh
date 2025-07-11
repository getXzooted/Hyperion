#!/bin/bash
# Component: flux
# Installs the FluxCD GitOps engine into the cluster.


set -e


# --- Configuration & Constants ---
GITHUB_REPO_URL="https://github.com/getXzooted/Hyperion"
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml


# These variables are now provided by the master-provisioner engine
if [ -z "$GITHUB_USER" ] || [ -z "$GITHUB_TOKEN" ]; then
  echo "  ---------> ERROR: GITHUB_USER and GITHUB_TOKEN must be set. <---------  "
  exit 1
fi


echo "  ---------> Waiting for K3s API server to be available <---------  "
until kubectl get nodes >/dev/null 2>&1; do sleep 5; done


echo "  ---------> Installing the FluxCD CLI <---------  "
curl -s https://fluxcd.io/install.sh | sudo bash


echo "  ---------> Bootstrapping FluxCD with provided credentials <---------  "
echo "  ---------> Step 1: Installing Flux components into the cluster <---------  "
flux install

echo "  ---------> Step 2: Waiting for Flux controllers to become ready <---------  "
# This is a critical health check to ensure the engine is running before we give it work.
kubectl wait --for=condition=Ready pods -n flux-system --all --timeout=300s

echo "  ---------> Step 3: Creating the Git source and sync configuration <---------  "
# This creates the GitRepository and Kustomization manifests that tell Flux what to do.
flux create source git flux-system \
  --url=${GITHUB_REPO_URL} \
  --branch=main \
  --interval=1m \
  --export > ./gotk-sync.yaml

# Adding the YAML separator to create a valid multi-document file.
echo "---" >> ./gotk-sync.yaml

flux create kustomization flux-system \
  --source=flux-system \
  --path="./kubernetes/base" \
  --prune=true \
  --validation=client \
  --interval=10m \
  --export >> ./gotk-sync.yaml

echo "  ---------> Step 4: Applying the sync configuration to the cluster <---------  "
# Now that the cluster is ready, we apply our configuration for the first time.
kubectl apply -f ./gotk-sync.yaml


echo "  ---------> FluxCD Task Complete. <---------  "