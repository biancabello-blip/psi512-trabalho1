#!/bin/bash

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_DIR="hpa-test-$TIMESTAMP"

minikube service python-web &
SERVICE_PID=$!

mkdir -p "$LOG_DIR"

echo "=== Iniciando teste de HPA ==="
echo "Logs serão salvos em: $LOG_DIR"

echo "[1/3] Iniciando load gen..."
kubectl run load-generator \
  --image=busybox:1.36 \
  --restart=Never \
  -- /bin/sh -c 'while true; do wget -q -O- http://python-web:8000 > /dev/null; done'

echo "[2/3] Monitorando HPA..."
kubectl get hpa -w \
  > "$LOG_DIR/hpa.log" 2>&1 &
HPA_PID=$!

echo "[3/3] Monitorando Pods..."
kubectl get pods -w \
  > "$LOG_DIR/pods.log" 2>&1 &
PODS_PID=$!

echo ""
echo "Teste em execução."
echo "  HPA  -> $LOG_DIR/hpa.log"
echo "  Pods -> $LOG_DIR/pods.log"
echo "  Load -> $LOG_DIR/load-generator.log"
echo ""
echo "Pressione ENTER para encerrar o teste."

read

echo ""
echo "Encerrando monitoramento..."

kill "$HPA_PID" 2>/dev/null
kill "$PODS_PID" 2>/dev/null
kill "$SERVICE_PID" 2>/dev/null

echo "Removendo CPU load..."
kubectl delete pod load-generator \
  > "$LOG_DIR/load-generator-delete.log" 2>&1

echo "Teste finalizado."
echo "Logs disponíveis em: $LOG_DIR"