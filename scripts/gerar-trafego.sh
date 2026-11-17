#!/usr/bin/env bash
# Gera requisições na aplicação para:
#  1) mostrar no terminal o balanceamento entre as réplicas
#  2) produzir métricas, logs e traces para o Grafana
set -euo pipefail
URL=$(minikube service app-service --url)
N=${1:-20}

echo "== Quem respondeu cada requisição (balanceamento entre réplicas) =="
for i in $(seq 1 "$N"); do
  curl -s "$URL/api/info"; echo
done | sort | uniq -c

echo
echo "== Gravando notas no banco =="
for i in $(seq 1 5); do
  curl -s -o /dev/null -X POST -d "texto=Nota de teste $i gerada pelo script" "$URL/notas"
done
curl -s "$URL/api/notas" | head -c 600; echo
