#!/bin/bash

eval $(minikube docker-env)

minikube addons enable metrics-server

docker build -t python-web:1.0 .

docker images | grep python-web

kubectl apply -f deployment.yaml

kubectl get deployments
kubectl get pods -o wide

kubectl apply -f service.yaml

kubectl get service python-web
kubectl get hpa
