#!/bin/bash
set -e
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# --- 1. Lancer K3s master 1 (primary) avec etcd intégré ---
# Sur la machine MASTER 1 :
curl -sfL https://get.k3s.io | sh -s - server \
  --cluster-init \
  --node-label "node-role=master" \
  --disable traefik \
  --tls-san "$(hostname -I | awk '{print $1}')"

# Récupérer le token pour les autres nœuds
K3S_TOKEN=$(cat /var/lib/rancher/k3s/server/node-token)
MASTER1_IP=$(hostname -I | awk '{print $1}')
echo "Token : $K3S_TOKEN"
echo "IP master 1 : $MASTER1_IP"

# --- 2. Sur la machine MASTER 2 (à exécuter sur master2) ---
# curl -sfL https://get.k3s.io | sh -s - server \
#   --server https://${MASTER1_IP}:6443 \
#   --token ${K3S_TOKEN} \
#   --node-label "node-role=master" \
#   --disable traefik

# --- 3. Sur chaque WORKER (à exécuter sur chaque worker) ---
# Remplacer ROLE par : app-1, app-2, monitoring, argocd
# curl -sfL https://get.k3s.io | K3S_URL=https://${MASTER1_IP}:6443 \
#   K3S_TOKEN=${K3S_TOKEN} sh -s - agent \
#   --node-label "node-role=ROLE"

# --- 4. Appliquer les taints pour isoler les workers ---
kubectl taint nodes worker-monitoring dedicated=monitoring:NoSchedule
kubectl taint nodes worker-argocd   dedicated=argocd:NoSchedule

# --- 5. Déployer les manifestes ---
kubectl apply -f k8s-projet/mysql-secret.yaml
kubectl apply -f k8s-projet/mysql-configmap.yaml
kubectl apply -f k8s-projet/mysql-deployment.yaml
kubectl apply -f k8s-projet/web-deployment.yaml
kubectl apply -f k8s-projet/ingress.yaml

echo "Cluster HA initialisé."
