#!/bin/bash
set -e
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "Vérification de Helm..."
if ! command -v helm &> /dev/null; then
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

echo "Installation de Prometheus et Grafana avec limites RAM et node affinity..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install kube-stack prometheus-community/kube-prometheus-stack \
    --namespace monitoring --create-namespace \
    -f k8s-projet/boost-ram.yaml \
    --wait --timeout 5m

echo "Monitoring installé sur worker-monitor."
