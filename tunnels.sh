#!/bin/bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
LOG_FILE="/tmp/tunnels-startup.log"
exec > >(tee -a ${LOG_FILE})
exec 2> >(tee -a ${LOG_FILE} >&2)

echo "--- Début de tunnels.sh à $(date) ---"

echo "Attente que K3s soit prêt (2 masters attendus)..."
until kubectl get nodes | grep -c " Ready" | grep -q "[2-9]"; do
    sleep 5
done
echo "Cluster prêt : $(kubectl get nodes --no-headers | grep Ready | wc -l) nœuds Ready"

if kubectl get namespace argocd > /dev/null 2>&1; then
    kubectl scale deployment argocd-server argocd-repo-server argocd-dex-server \
        argocd-notifications-controller -n argocd --replicas=1 2>/dev/null || true
    kubectl scale statefulset argocd-application-controller -n argocd --replicas=1 2>/dev/null || true
fi

if kubectl get namespace monitoring > /dev/null 2>&1; then
    kubectl scale deployment kube-stack-kube-prometheus-operator kube-stack-grafana \
        -n monitoring --replicas=1 2>/dev/null || true
    kubectl scale statefulset prometheus-kube-stack-kube-prometheus-prometheus \
        alertmanager-kube-stack-kube-prometheus-alertmanager \
        -n monitoring --replicas=1 2>/dev/null || true
fi

echo "Attente de 20 secondes pour laisser les pods démarrer..."
sleep 20

echo "Nettoyage des anciens tunnels..."
pkill -f "port-forward" 2>/dev/null || true
sleep 2

echo "Ouverture des tunnels..."
if kubectl get svc web-service > /dev/null 2>&1; then
    nohup kubectl port-forward svc/web-service 8081:80 --address 0.0.0.0 \
        > /tmp/port-forward-web.log 2>&1 &
fi
if kubectl get svc argocd-server -n argocd > /dev/null 2>&1; then
    nohup kubectl port-forward svc/argocd-server -n argocd 8085:80 --address 0.0.0.0 \
        > /tmp/port-forward-argo.log 2>&1 &
fi
if kubectl get svc kube-stack-grafana -n monitoring > /dev/null 2>&1; then
    nohup kubectl port-forward svc/kube-stack-grafana -n monitoring 8082:80 --address 0.0.0.0 \
        > /tmp/port-forward-grafana.log 2>&1 &
fi

echo "Tunnels activés. Cluster HA opérationnel."
