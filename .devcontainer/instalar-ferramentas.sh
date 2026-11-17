#!/usr/bin/env bash
# Instala kubectl, helm, minikube e socat no Codespace.
# Roda sozinho ao criar o Codespace; se falhar, pode ser executado de novo:
#   bash .devcontainer/instalar-ferramentas.sh
set -euo pipefail

echo ">> Instalando socat..."
sudo apt-get update -qq
sudo apt-get install -y -qq socat curl

echo ">> Instalando kubectl..."
KVER=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
curl -fsSLo /tmp/kubectl "https://dl.k8s.io/release/${KVER}/bin/linux/amd64/kubectl"
sudo install -m 0755 /tmp/kubectl /usr/local/bin/kubectl

echo ">> Instalando helm..."
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo ">> Instalando minikube..."
curl -fsSLo /tmp/minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install -m 0755 /tmp/minikube /usr/local/bin/minikube

chmod +x scripts/*.sh

echo
echo ">> Versões instaladas:"
kubectl version --client
helm version --short
minikube version --short
docker --version || echo "(docker ainda iniciando - abra um novo terminal)"
echo ">> Ferramentas prontas!"
