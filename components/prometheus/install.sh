#!/bin/bash
# Component: prometheus


set -e


export KUBECONFIG=/etc/rancher/k3s/k3s.yaml


echo "  -> Deploying Prometheus Operator Bundle..."
kubectl apply -k /opt/Hyperion/kubernetes/apps/prometheus/

echo "  -> Waiting for Observability Stack to become ready..."
# We wait for the three main deployments from the bundle
kubectl wait --for=condition=available -n default deployment/prometheus-operator --timeout=300s
kubectl wait --for=condition=available -n default deployment/grafana --timeout=180s
echo "  -> Prometheus Operator and Grafana are ready."
echo "  -> Waiting for Prometheus server to be ready..."
kubectl wait --for=condition=Ready -n default statefulset/prometheus-prometheus --timeout=300s

echo "  -> Observability Stack installed successfully."