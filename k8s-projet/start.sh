#!/bin/bash
set -e
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "Attente que le cluster soit prêt..."
until kubectl get nodes > /dev/null 2>&1; do sleep 3; done
kubectl get nodes

echo "Installation d'ArgoCD sur worker-argocd..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Patch ArgoCD pour tolérer le taint du nœud dédié
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl patch deployment argocd-server -n argocd --type='json' -p='[
  {"op":"add","path":"/spec/template/spec/nodeSelector","value":{"node-role":"argocd"}},
  {"op":"add","path":"/spec/template/spec/tolerations","value":[{"key":"dedicated","operator":"Equal","value":"argocd","effect":"NoSchedule"}]}
]' 2>/dev/null || true

echo "Déploiement des Secrets et de MySQL..."
kubectl apply -f k8s-projet/mysql-secret.yaml
kubectl apply -f k8s-projet/mysql-configmap.yaml
kubectl apply -f k8s-projet/mysql-deployment.yaml

echo "Déploiement de l'application web..."
kubectl apply -f k8s-projet/web-deployment.yaml
kubectl apply -f k8s-projet/ingress.yaml

echo "Cluster HA opérationnel."
