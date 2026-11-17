#!/usr/bin/env bash
# Abre o acesso à App (porta 8080) e ao Grafana (porta 3000) a partir do navegador.
# - App: socat repassa para o NodePort do Minikube -> passa pelo Service -> balanceia entre as réplicas.
# - Grafana: port-forward para o Service do Grafana.
set -uo pipefail

pkill -f "socat TCP-LISTEN:8080" 2>/dev/null || true
pkill -f "port-forward.*kps-grafana" 2>/dev/null || true

MINIKUBE_IP=$(minikube ip)
nohup socat TCP-LISTEN:8080,fork,reuseaddr TCP:"$MINIKUBE_IP":30080 >/tmp/socat-app.log 2>&1 &
nohup kubectl port-forward -n observabilidade svc/kps-grafana 3000:80 --address 0.0.0.0 >/tmp/pf-grafana.log 2>&1 &
sleep 2

echo "URL interna da app (minikube service): $(minikube service app-service --url)"
echo
echo "Abra a aba PORTS do Codespaces e clique no ícone de globo:"
echo "  - porta 8080 -> App Notas"
echo "  - porta 3000 -> Grafana (usuário: admin / senha: admin123)"
