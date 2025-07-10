#!/bin/bash
# Component: flux
# Installs the FluxCD GitOps engine into the cluster.
set -e

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
flux bootstrap github \
  --owner="$GITHUB_USER" \
  --repository=Hyperion \
  --branch=main \
  --path=./kubernetes/base/flux-system \
  --personal

echo "  ---------> FluxCD Task Complete. <---------  "