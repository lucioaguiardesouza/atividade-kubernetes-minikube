#!/usr/bin/env bash
# Sobe TODO o ambiente de uma vez (use no dia da apresentação).
# Na primeira vez, prefira executar etapa por etapa seguindo o README, para aprender.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "===== Etapa 1: Minikube ====="
if ! minikube status >/dev/null 2>&1; then
  minikube start --driver=docker --cpus=4 --memory=10240
fi
kubectl get nodes

echo "===== Etapa 2: Banco de dados ====="
kubectl apply -f k8s/banco/
kubectl rollout status deployment/postgres --timeout=180s

echo "===== Etapa 3: Aplicação (build da imagem dentro do Minikube) ====="
minikube image build -t app-notas:1.0 ./app
kubectl apply -f k8s/app/
kubectl rollout status deployment/app-notas --timeout=180s

echo "===== Etapa 4: Observabilidade ====="
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana-community https://grafana-community.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

kubectl create namespace observabilidade --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install kps prometheus-community/kube-prometheus-stack \
  -n observabilidade -f k8s/observabilidade/kube-prometheus-stack-values.yaml --wait --timeout 15m
helm upgrade --install loki grafana-community/loki \
  -n observabilidade -f k8s/observabilidade/loki-values.yaml --wait --timeout 10m
helm upgrade --install tempo grafana-community/tempo \
  -n observabilidade -f k8s/observabilidade/tempo-values.yaml --wait --timeout 10m
helm upgrade --install otel-collector open-telemetry/opentelemetry-collector \
  -n observabilidade -f k8s/observabilidade/otel-collector-values.yaml --wait --timeout 10m
kubectl apply -f k8s/observabilidade/grafana-dashboard-configmap.yaml

echo
echo "===== Tudo pronto! ====="
kubectl get pods -A
echo
echo "Agora rode: ./scripts/acessar.sh"
