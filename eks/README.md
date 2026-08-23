# Implantação B — Cluster Kubernetes gerenciado na AWS (Amazon EKS)

Contraparte, na nuvem, da Implantação A (Minikube) que está na raiz deste
repositório. A aplicação, o `Dockerfile`, os *requests*/*limits* de CPU e os
parâmetros do HPA (`minReplicas`, `maxReplicas`, `averageUtilization`) são
**idênticos** aos da Implantação A — é essa igualdade que torna a comparação
do artigo legítima. Tudo o que muda entre as duas implantações muda por
necessidade do ambiente, e cada diferença está comentada no arquivo em que
aparece.

## O que difere da Implantação A, e por quê

| Aspecto | A — Minikube | B — AWS EKS | Motivo |
|---|---|---|---|
| Imagem | construída no daemon da VM (`minikube docker-env`), `imagePullPolicy: Never` | publicada no Amazon ECR e baixada pelo node | cada node é uma instância EC2 sem acesso ao Docker local |
| Métricas | `minikube addons enable metrics-server` | manifesto oficial aplicado à mão | o EKS não instala o metrics-server, e sem ele o HPA fica em `<unknown>` |
| Exposição | `NodePort` + túnel `minikube service` | `LoadBalancer` → Classic Load Balancer com DNS público | não há host único para tunelar; o acesso vem da VPC |
| Nodes | 1 (a própria VM) | 2 × `t3.medium` | permite observar o *scheduler* distribuindo os Pods do HPA entre máquinas |
| Custo | zero | ~US$ 0,17/h enquanto o cluster existir | plano de controle + EC2 + EBS + balanceador |
| Criação | ~40 s | ~15 min | provisionamento de VPC, IAM, plano de controle e node group |

## Pré-requisitos

Ferramentas na estação de trabalho: `aws` (CLI v2), `eksctl`, `kubectl`,
`docker`, `curl`. Conta AWS própria, com identidade IAM administrativa
**não-root**.

```bash
aws sts get-caller-identity   # deve responder com a identidade correta
```

> **Custo.** O percurso completo custa entre US$ 2 e US$ 4 se executado em uma
> sessão de poucas horas. O maior desperdício possível é deixar o cluster
> ligado sem uso: o plano de controle é cobrado por hora mesmo ocioso. Rode o
> `99-cleanup.sh` no mesmo dia.

## Execução

Os scripts são numerados na ordem em que devem rodar e cada um imprime o
próximo passo ao terminar. Todas as evidências são gravadas em `evidencias/`.

```bash
cd eks

./00-build-push-ecr.sh    # cria o repositório ECR, constrói e envia a imagem
./01-create-cluster.sh    # eksctl: VPC, IAM, plano de controle, node group (~15 min)
./02-metrics-server.sh    # instala o metrics-server e comprova antes/depois
./03-deploy-app.sh        # Deployment + HPA + Service LoadBalancer, aguarda o DNS
./20-load-test.sh         # experimento de carga em três fases (~13 min)
./99-cleanup.sh           # remove tudo na ordem correta e verifica por API
```

O `20-load-test.sh` aceita parâmetros para repetir o experimento com outra
intensidade — útil para a análise comparativa:

```bash
./20-load-test.sh 60 300 420 1    # padrão: 1 gerador de carga
./20-load-test.sh 60 300 420 3    # 3 geradores concorrentes
```

### Screenshots obrigatórios

O enunciado exige evidências fotográficas. Capture, no mínimo:

1. `kubectl get nodes -o wide` — os dois nodes EC2 prontos
2. `kubectl top nodes` **antes** e **depois** do `02-metrics-server.sh`
3. A aplicação aberta no navegador, no hostname do balanceador
4. `kubectl get hpa -w` durante a subida das réplicas
5. `kubectl get pods -o wide` no pico — mostrando os Pods **em nodes distintos**
6. O console da AWS: cluster EKS, instâncias EC2 e o balanceador
7. A verificação final de limpeza, com todas as listas vazias

O item 5 é o que a Implantação A não consegue produzir, e por isso vale o
enquadramento cuidadoso.

## Saídas do experimento

O `20-load-test.sh` grava em `evidencias/teste-carga-eks-<timestamp>/`:

| Arquivo | Conteúdo |
|---|---|
| `metricas.csv` | série temporal a cada 5 s: CPU, réplicas desejadas, réplicas atuais, Pods prontos — pronta para virar gráfico |
| `RESUMO.txt` | números fechados: CPU máxima, réplicas máximas, tempo até a primeira expansão, tempo até o máximo |
| `hpa-describe.txt` | eventos do HPA com o motivo textual de cada decisão |
| `hpa-watch.log`, `pods-watch.log` | fluxo bruto de mudanças |
| `eventos.log` | horário absoluto de cada marco das três fases |

O `metricas.csv` é o insumo do gráfico central do artigo. Um mínimo em
gnuplot ou matplotlib:

```bash
python3 - <<'PY'
import csv, matplotlib.pyplot as plt
t, cpu, rep = [], [], []
for r in csv.DictReader(open('metricas.csv')):
    t.append(int(r['t_s'])/60)
    cpu.append(float(r['cpu_atual_pct']) if r['cpu_atual_pct'] != 'NA' else 0)
    rep.append(int(r['replicas_atuais']))
fig, ax = plt.subplots(figsize=(8, 4))
ax.plot(t, cpu, label='CPU (% do request)')
ax.set_xlabel('tempo (min)'); ax.set_ylabel('CPU (%)')
ax2 = ax.twinx(); ax2.step(t, rep, where='post', color='tab:red', label='réplicas')
ax2.set_ylabel('réplicas')
fig.legend(loc='upper left'); fig.tight_layout(); fig.savefig('hpa-eks.png', dpi=150)
PY
```

## Por que três fases

O HPA sobe rápido e desce devagar, e a assimetria é de projeto: expandir tarde
custa disponibilidade, contrair cedo custa estabilidade. A janela de
estabilização padrão para redução é de **300 segundos** — o controlador só
reduz réplicas depois de cinco minutos observando demanda menor. A fase de
recuperação do teste dura 420 s justamente para que esse comportamento apareça
nos dados em vez de ser apenas citado. O script da Implantação A encerra logo
após remover a carga e, por isso, não registra o *scale-down*.

## Limpeza

```bash
./99-cleanup.sh
```

Remove nesta ordem: gerador de carga → Service (e aguarda o balanceador sumir
de fato) → aplicação e HPA → cluster inteiro via `eksctl` → repositório ECR.
Termina verificando por API que clusters, instâncias, balanceadores, volumes,
repositórios, pilhas CloudFormation, roles e *instance profiles* não deixaram
resíduo.
