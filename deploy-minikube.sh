#!/bin/bash
# =============================================================================
# PSI512 - Trabalho Avaliativo 1 - Implantacao A (Minikube)
# Implantacao da aplicacao, do Service e do HPA no cluster local.
#
# Equivalente local dos scripts 00 a 03 da pasta eks/. A diferenca de tamanho
# entre este arquivo e aqueles e, por si, um resultado do trabalho: no Minikube
# nao ha registro de imagens a criar, nem VPC, nem roles IAM, nem plano de
# controle a provisionar.
#
# Pre-requisito: "minikube start".
# =============================================================================

# Aponta o cliente Docker do host para o daemon que roda DENTRO da VM do
# Minikube. Sem isso a imagem seria construida no daemon do host e o kubelet da
# VM nao a encontraria - erro ErrImageNeverPull, ja que o Deployment usa
# imagePullPolicy: Never.
eval $(minikube docker-env)

# Habilita o metrics-server, que fornece a API metrics.k8s.io consultada pelo
# HPA. Sem ele o HPA fica indefinidamente em "cpu: <unknown>/10%" e nunca
# escala. No EKS este componente nao existe por padrao e precisa ser instalado
# a partir do manifesto oficial - ver eks/02-metrics-server.sh.
minikube addons enable metrics-server

# Constroi a imagem dentro da VM. O mesmo Dockerfile e usado na Implantacao B.
docker build -t python-web:1.0 .

docker images | grep python-web

# Cria Deployment e HorizontalPodAutoscaler (ambos no mesmo arquivo).
kubectl apply -f deployment.yaml

kubectl get deployments
kubectl get pods -o wide

# Cria o Service NodePort.
kubectl apply -f service.yaml

kubectl get service python-web

# Logo apos o apply o HPA ainda aparece com "<unknown>": o metrics-server leva
# cerca de um minuto para publicar a primeira janela de amostras.
kubectl get hpa
