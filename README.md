# PSI512 — Trabalho Avaliativo 1

Servidor web em Kubernetes com **Horizontal Pod Autoscaler (HPA)**, implantado
em dois ambientes e submetido ao mesmo experimento de carga:

- **Implantação A — Minikube** (cluster local)
- **Implantação B — AWS EKS** (cluster gerenciado na nuvem)

A aplicação, o `Dockerfile` e os parâmetros do HPA são **idênticos** nos dois
ambientes. Tudo o que difere, difere por necessidade do ambiente e está
comentado no arquivo em que aparece.

## Estrutura do repositório

```
app.py, index.html, Dockerfile     aplicação (comum às duas implantações)
deployment.yaml, service.yaml      manifestos da Implantação A
deploy-minikube.sh                 implantação no Minikube
minikube/
  12-load-generator.yaml           gerador de carga (Implantação A)
  20-load-test.sh                  experimento de carga
  evidencias/                      resultados coletados
eks/
  00-config.sh                     variáveis compartilhadas
  00-build-push-ecr.sh             publica a imagem no Amazon ECR
  01-create-cluster.sh             cria o cluster com eksctl
  02-metrics-server.sh             instala o metrics-server
  03-deploy-app.sh                 Deployment + HPA + Service LoadBalancer
  10/11/12-*.yaml                  manifestos da Implantação B
  20-load-test.sh                  experimento de carga
  99-cleanup.sh                    remoção e verificação por API
  evidencias/                      resultados coletados
common/
  hpa-test.sh                      instrumento de medição (usado pelas duas)
  plot-hpa.py                      gera o gráfico a partir do CSV
```

## O instrumento de medição é um só

`common/hpa-test.sh` é chamado tanto por `minikube/20-load-test.sh` quanto por
`eks/20-load-test.sh`. A escolha é metodológica: o enunciado pede análise
comparativa, e uma comparação só é válida se as duas medidas forem tomadas com
o mesmo instrumento — mesmo período de amostragem, mesmas fases, mesmas
grandezas, mesmo formato de saída.

O experimento tem três fases cronometradas:

| Fase | Padrão | O que se observa |
|---|---|---|
| Repouso | 60 s | linha de base sem carga |
| Carga | 300 s | *scale-up*: tempo até a primeira expansão e até o máximo |
| Recuperação | 420 s | *scale-down*, que só ocorre após a janela de estabilização de 300 s |

A saída é um `metricas.csv` amostrado a cada 5 s, com instante absoluto e
relativo, CPU, réplicas desejadas, réplicas atuais e Pods prontos — mais um
`RESUMO.txt` com os tempos de reação já calculados.

## Como executar

**Implantação A (local, gratuita):**

```bash
minikube start
./deploy-minikube.sh
cd minikube && ./20-load-test.sh 60 300 420 2
```

**Implantação B (AWS, ~US$ 0,21/h):** ver [`eks/README.md`](eks/README.md).

**Gráfico comparativo:**

```bash
common/plot-hpa.py minikube/evidencias/teste-carga-minikube-*/metricas.csv \
                   eks/evidencias/teste-carga-eks-*/metricas.csv \
                   --comparar comparativo.png
```

## Referências

1. Kubernetes — [Horizontal Pod Autoscaler Walkthrough](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/)
2. AWS EKS — [Scale pod deployments with Horizontal Pod Autoscaler](https://docs.aws.amazon.com/eks/latest/userguide/horizontal-pod-autoscaler.html)
