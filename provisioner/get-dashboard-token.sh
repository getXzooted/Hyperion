#!/bin/bash
# Helper script to get a login token for the Kubernetes Dashboard


set -e


export KUBECONFIG=/etc/rancher/k3s/k3s.yaml


echo "---[ Generating Kubernetes Dashboard Token ]---"
echo "This token is valid for 1 hour."
echo ""
kubectl -n kubernetes-dashboard create token admin-user --duration=1h
echo ""
echo "---[ To access the dashboard, run 'kubectl proxy' and open a browser to the local URL ]---"