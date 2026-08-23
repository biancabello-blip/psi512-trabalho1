#!/usr/bin/env bash
# =============================================================================
# PSI512 - Trabalho Avaliativo 1 - Implantacao B (AWS EKS)
# Etapa 0: publicar a imagem da aplicacao no Amazon ECR.
#
# Por que esta etapa nao existe na Implantacao A: no Minikube o comando
# "eval $(minikube docker-env)" aponta o cliente Docker do host para o daemon
# de dentro da VM do Minikube, de modo que a imagem construida ja nasce
# visivel ao kubelet e "imagePullPolicy: Never" basta. No EKS cada node e uma
# instancia EC2 independente, sem acesso ao daemon Docker do aluno; a imagem
# precisa estar em um registro alcancavel pela rede. O Amazon ECR e o registro
# privado da propria conta, e a permissao de leitura ja vem na role dos nodes
# (AmazonEC2ContainerRegistryPullOnly / ReadOnly), sem configuracao extra.
#
# Executar a partir da raiz do repositorio ou de dentro de eks/.
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"
source ./00-config.sh

# O Dockerfile, app.py e index.html sao os MESMOS da Implantacao A: a imagem
# executada no EKS e byte a byte equivalente a executada no Minikube. Isso e
# condicao para que a comparacao entre os dois ambientes seja legitima.
BUILD_CTX="$(cd .. && pwd)"

echo "== Conta AWS ...: ${AWS_ACCOUNT_ID}"
echo "== Regiao ......: ${AWS_REGION}"
echo "== Imagem ......: ${IMAGE}"
echo

# 1) Cria o repositorio no ECR. O "|| true" torna o script idempotente: se o
#    repositorio ja existir a AWS retorna RepositoryAlreadyExistsException e a
#    execucao prossegue.
echo "[1/4] Criando repositorio no ECR (ignora se ja existir)..."
aws ecr create-repository \
  --repository-name "${ECR_REPO}" \
  --region "${AWS_REGION}" \
  --image-scanning-configuration scanOnPush=true \
  >/dev/null 2>&1 || true

# 2) Autentica o Docker local no ECR. O token retornado por get-login-password
#    e temporario (12 horas) e derivado da sessao atual - nao ha senha estatica
#    gravada em disco.
echo "[2/4] Autenticando o Docker no ECR..."
aws ecr get-login-password --region "${AWS_REGION}" \
  | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# 3) Constroi a imagem. --platform=linux/amd64 e explicito porque os nodes sao
#    t3.medium (x86_64): se a estacao de trabalho do aluno for ARM (Apple
#    Silicon, por exemplo), uma imagem construida sem esta flag falharia no
#    cluster com "exec format error".
echo "[3/4] Construindo a imagem..."
docker build --platform=linux/amd64 -t "${IMAGE}" "${BUILD_CTX}"

# 4) Envia ao registro.
echo "[4/4] Enviando a imagem ao ECR..."
docker push "${IMAGE}"

echo
echo "Imagem publicada: ${IMAGE}"
