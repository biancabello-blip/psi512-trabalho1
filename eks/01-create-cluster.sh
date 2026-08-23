#!/usr/bin/env bash
# =============================================================================
# PSI512 - Trabalho Avaliativo 1 - Implantacao B (AWS EKS)
# Etapa 1: criar o cluster gerenciado.
#
# Equivalente, na nuvem, ao "minikube start" da Implantacao A - e a comparacao
# entre os dois comandos e um dos resultados do trabalho. O minikube start
# leva dezenas de segundos e cria uma VM local. O comando abaixo leva cerca de
# 15 minutos e provisiona, por CloudFormation: uma VPC com subnets publicas em
# tres zonas de disponibilidade, tabelas de rota, internet gateway, security
# groups, duas roles IAM (uma para o plano de controle, outra para os nodes),
# o plano de controle gerenciado e um managed node group com instancias EC2.
#
# O eksctl e a ferramenta indicada pela documentacao da AWS referenciada no
# enunciado (Referencia 2).
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"
source ./00-config.sh
mkdir -p "${EVID_DIR}"

echo "== Criando cluster ${CLUSTER_NAME} em ${AWS_REGION}"
echo "== Isso leva aproximadamente 15 minutos."
date

# --managed  : node group gerenciado pela AWS (ciclo de vida das instancias,
#              atualizacoes e drenagem sob responsabilidade do servico).
# --nodes-min/--nodes-max iguais a --nodes: o node group NAO escala. Isso e
#              deliberado. O objeto de estudo do trabalho e o Horizontal Pod
#              Autoscaler, que escala PODS. Manter o numero de nodes fixo
#              isola a variavel e evita que o Cluster Autoscaler mascare o
#              efeito observado. A distincao entre escalar Pods e escalar
#              nodes e discutida no artigo.
# --node-volume-size 20 : disco minimo, para reduzir custo de EBS.
# --with-oidc : habilita o provedor OIDC, pre-requisito para associar
#              permissoes IAM a ServiceAccounts. Nao e usado por esta
#              aplicacao, mas e criado sem custo e evita recriar o cluster
#              caso o grupo decida instalar o AWS Load Balancer Controller.
eksctl create cluster \
  --name "${CLUSTER_NAME}" \
  --region "${AWS_REGION}" \
  --nodegroup-name ng-default \
  --node-type "${NODE_TYPE}" \
  --nodes "${NODE_COUNT}" \
  --nodes-min "${NODE_COUNT}" \
  --nodes-max "${NODE_COUNT}" \
  --node-volume-size 20 \
  --managed \
  --with-oidc

date
echo
echo "== Configurando o kubeconfig local"
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_REGION}"

echo
echo "== EVIDENCIA: nodes do cluster"
kubectl get nodes -o wide | tee "${EVID_DIR}/E1-nodes.txt"

echo
echo "== EVIDENCIA: Pods de sistema"
kubectl get pods -n kube-system -o wide | tee "${EVID_DIR}/E1-kube-system.txt"

echo
echo "Cluster pronto. Proximo passo: ./02-metrics-server.sh"
