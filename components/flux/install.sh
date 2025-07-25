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

echo "  ---------> Step 3: Waiting for Flux CRDs to be established in the cluster <---------  "
kubectl wait --for condition=established --timeout=300s crd/gitrepositories.source.toolkit.fluxcd.io
kubectl wait --for condition=established --timeout=300s crd/kustomizations.kustomize.toolkit.fluxcd.io


echo "  ---------> FluxCD Task Complete. <---------  "