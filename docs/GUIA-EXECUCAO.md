# Guia de execução — do zero às evidências

Roteiro passo a passo das duas implantações, escrito para ser seguido por
alguém que não participou da montagem do repositório. Atende ao item
*"Roteiros de Implantação e Testes"* do enunciado e serve para que cada
integrante do grupo faça a sua própria execução, como exige a regra de
**execução prática individual**.

Tempo total: cerca de **1h30**, sendo ~40 min de espera (provisionamento e
teste). Custo: **US$ 0** na Implantação A, **US$ 2 a 4** na Implantação B.

> **Cada pessoa usa a própria conta AWS.** Os nomes de recurso são os mesmos
> em todas as execuções, o que não causa conflito por estarem em contas
> distintas. Se por algum motivo duas pessoas usarem a mesma conta, veja
> [Executando na mesma conta](#executando-na-mesma-conta).

---

## Sumário

1. [Ferramentas](#1-ferramentas)
2. [Implantação A — Minikube](#2-implantação-a--minikube)
3. [Credenciais AWS](#3-credenciais-aws)
4. [Implantação B — AWS EKS](#4-implantação-b--aws-eks)
5. [Limpeza — não pule](#5-limpeza--não-pule)
6. [Evidências a coletar](#6-evidências-a-coletar)
7. [Problemas comuns](#7-problemas-comuns)

---

## 1. Ferramentas

| Ferramenta | Implantação A | Implantação B |
|---|:--:|:--:|
| `docker` | sim | sim |
| `minikube` | sim | — |
| `kubectl` | sim | sim |
| `aws` (CLI v2) | — | sim |
| `eksctl` | — | sim |
| `python3` + `matplotlib` | opcional (gráfico) | opcional (gráfico) |

### Linux

```bash
# AWS CLI v2
curl -sL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip -q awscliv2.zip && sudo ./aws/install --update

# eksctl
curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" \
  | tar xz && sudo install -m 755 eksctl /usr/local/bin/eksctl

# minikube e kubectl: pelo gerenciador de pacotes da distribuição
```

Se o daemon do Docker não estiver rodando: `sudo systemctl start docker`.

### macOS

```bash
brew install awscli eksctl minikube kubectl
```

Em Mac com chip Apple Silicon, veja
[imagem com arquitetura errada](#a-imagem-não-executa-no-eks-exec-format-error).

### Windows

Use **WSL2** e siga as instruções de Linux. O Docker Desktop precisa estar com
a integração WSL ativada. Executar os scripts direto no PowerShell não
funciona — são scripts de shell.

### Confira antes de seguir

```bash
docker info --format '{{.ServerVersion}}'
minikube version
kubectl version --client
aws --version
eksctl version
```

---

## 2. Implantação A — Minikube

Cluster local, sem custo. Comece por aqui: valida a aplicação e o HPA antes de
gastar dinheiro na nuvem.

```bash
git clone https://github.com/biancabello-blip/psi512-trabalho1.git
cd psi512-trabalho1

minikube start --driver=docker --cpus=4 --memory=6g
./deploy-minikube.sh
```

O `deploy-minikube.sh` aponta o Docker para o daemon de dentro da VM, habilita
o metrics-server, constrói a imagem e aplica Deployment, HPA e Service.

**Espere o metrics-server publicar a primeira amostra** — leva cerca de um
minuto. Antes disso o HPA aparece como `cpu: <unknown>/10%`, e o teste
produziria uma coluna inteira de `NA`:

```bash
watch -n5 kubectl get hpa
# siga quando aparecer algo como  cpu: 2%/10%
```

Agora o experimento. **Grave suas evidências numa pasta com o seu nome**, para
não misturar com as dos colegas:

```bash
cd minikube
EVID_DIR=$PWD/evidencias/SEU-NOME ./20-load-test.sh 60 300 420 2
```

Os quatro números são repouso, carga, recuperação (em segundos) e quantidade de
geradores de carga. **Use exatamente estes valores** — são os mesmos da
Implantação B, e é isso que torna as duas medidas comparáveis.

O teste leva **13 minutos** e não precisa de supervisão. Ao final imprime o
resumo com os tempos de reação. Gráfico:

```bash
cd ..
common/plot-hpa.py minikube/evidencias/SEU-NOME/teste-carga-minikube-*/metricas.csv
```

Encerrando o cluster local (a qualquer momento, sem custo pendente):

```bash
minikube delete
```

---

## 3. Credenciais AWS

A Implantação B precisa do AWS CLI autenticado **nesta máquina**. Não dá para
usar apenas o CloudShell: ele não tem daemon Docker, e a imagem precisa ser
construída localmente para ser enviada ao ECR.

### Use um usuário IAM, não a conta root

O usuário root não pode ser restringido por política e existe para tarefas de
nível de conta. Se ainda não tiver um usuário administrativo:

**Console → IAM → Users → Create user** → marque *Provide user access to the
AWS Management Console* → anexe a política gerenciada `AdministratorAccess`.

### Crie a chave de acesso

**Console → IAM → Users → seu-usuário → Security credentials → Create access
key → Command line interface (CLI)**

```bash
aws configure
# AWS Access Key ID:     ...
# AWS Secret Access Key: ...
# Default region name:   us-east-1
# Default output format: json
```

Rode isso num terminal seu, não colando a chave em chat, issue ou commit.

Confirme — este comando mostra apenas identidade, nunca a chave:

```bash
aws sts get-caller-identity
```

> ### Apague a chave ao terminar
>
> Uma access key vale até ser revogada e vaza com facilidade — histórico do
> shell, screenshot, commit acidental. Crie hoje, use hoje, apague hoje:
>
> ```bash
> aws iam list-access-keys
> aws iam delete-access-key --access-key-id <ID>
> ```

---

## 4. Implantação B — AWS EKS

Cinco scripts, na ordem. Cada um imprime o próximo ao terminar.

```bash
cd eks
# Exporte UMA VEZ, no início da sessão: todos os scripts desta pasta gravam
# evidências aqui. Se você exportar só na hora do teste de carga, as
# evidências das etapas anteriores caem na pasta padrão e se misturam com as
# dos colegas.
export EVID_DIR=$PWD/evidencias/SEU-NOME
```

### 4.1 Publicar a imagem no ECR — ~2 min

```bash
./00-build-push-ecr.sh
```

Cria o repositório, autentica o Docker com um token temporário de 12 horas,
constrói a imagem para `linux/amd64` e envia. É a etapa que não existe no
Minikube: lá a imagem nasce visível ao kubelet; aqui cada node é uma instância
EC2 que só alcança a imagem por um registro na rede.

### 4.2 Criar o cluster — ~15 min

```bash
./01-create-cluster.sh
```

O `eksctl` provisiona, via CloudFormation: VPC com subnets em três zonas,
internet gateway, tabelas de rota, security groups, duas roles IAM, o plano de
controle gerenciado e um node group com 2 instâncias `t3.medium`.

**A partir daqui o relógio de custo está correndo** (~US$ 0,19/h). Não
interrompa o script no meio: um `Ctrl+C` deixa a pilha CloudFormation pela
metade e recursos cobrando. Se precisar abandonar, rode `./99-cleanup.sh`.

### 4.3 Instalar o metrics-server — ~2 min

```bash
./02-metrics-server.sh
```

**É aqui que o EKS mais difere do Minikube.** Lá o metrics-server é um addon
de uma linha; aqui o componente não vem instalado e não há addon gerenciado
equivalente. Sem ele o HPA fica permanentemente em `cpu: <unknown>/10%` e
nunca escala.

O script grava a saída do `kubectl top nodes` **antes** e **depois**. O erro do
"antes" é evidência, não falha — guarde-o.

### 4.4 Implantar a aplicação — ~5 min

```bash
./03-deploy-app.sh
```

Aplica Deployment, HPA e o Service do tipo `LoadBalancer`, e espera o
balanceador publicar um nome DNS. A propagação do DNS leva de 1 a 3 minutos
depois disso — o script aguarda até a aplicação responder.

Ao final ele imprime a URL. **Abra no navegador e tire um screenshot**: é
evidência obrigatória e não dá para recuperar depois da limpeza.

### 4.5 O experimento — 13 min

```bash
./20-load-test.sh 60 300 420 2
```

Mesmos parâmetros da Implantação A, de propósito. (O `EVID_DIR` já foi
exportado no início da seção 4.)

Enquanto roda, num **segundo terminal**, capture as telas que valem nota:

```bash
watch -n2 kubectl get hpa,pods -o wide
```

O momento mais importante é o pico: `kubectl get pods -o wide` mostrando os
Pods distribuídos **em nodes diferentes** — evidência que a Implantação A não
consegue produzir, porque tem um node só.

### 4.6 Gráfico comparativo

```bash
cd ..
common/plot-hpa.py \
  minikube/evidencias/SEU-NOME/teste-carga-minikube-*/metricas.csv \
  eks/evidencias/SEU-NOME/teste-carga-eks-*/metricas.csv \
  --comparar comparativo.png
```

---

## 5. Limpeza — não pule

```bash
cd eks
./99-cleanup.sh
```

**A ordem importa.** O balanceador de carga não pertence ao CloudFormation:
foi criado pelo cloud controller do Kubernetes em resposta ao objeto Service.
Excluir o cluster primeiro faz o controlador desaparecer e o balanceador
permanecer na conta — órfão, invisível no console do EKS e cobrado por hora. O
script apaga o Service antes e só prossegue quando confirma que o número de
balanceadores chegou a zero.

Leva ~12 minutos e termina verificando por API que nada sobrou: clusters,
instâncias, balanceadores, volumes, repositórios ECR, pilhas CloudFormation,
roles e instance profiles.

Depois disso:

1. Apague a access key (seção 3).
2. **Confira o Billing nos dias seguintes.** Verificação por API vazia
   comprova ausência de recursos, não ausência de cobrança — o Billing tem
   atraso de atualização.

---

## 6. Evidências a coletar

O enunciado exige capturas de tela do estado **antes, durante e depois** dos
testes. Mínimo por pessoa:

**Implantação A**
- [ ] `minikube start` concluído e `kubectl get nodes`
- [ ] `kubectl get hpa` com métrica válida (não `<unknown>`)
- [ ] `kubectl get pods` no pico, com 5 réplicas
- [ ] gráfico gerado a partir do `metricas.csv`

**Implantação B**
- [ ] `kubectl get nodes -o wide` — os dois nodes EC2
- [ ] `kubectl top nodes` **antes** e **depois** do metrics-server
- [ ] a aplicação aberta no navegador, na URL do balanceador
- [ ] `kubectl get hpa` durante a subida das réplicas
- [ ] **`kubectl get pods -o wide` no pico, com Pods em nodes distintos**
- [ ] console AWS: cluster EKS, instâncias EC2, balanceador
- [ ] verificação final de limpeza, com todas as listas vazias

Os arquivos gerados pelos scripts (`metricas.csv`, `RESUMO.txt`,
`hpa-describe.txt`, logs) ficam em `evidencias/SEU-NOME/` e devem ser
commitados — são parte da entrega.

### Executando na mesma conta

Se duas pessoas precisarem usar a mesma conta AWS, dê nomes distintos aos
recursos para não colidirem:

```bash
export CLUSTER_NAME=psi512-t1-eks-SEUNOME
export ECR_REPO=psi512-python-web-SEUNOME
```

Melhor ainda: **não executem em paralelo**. Dois clusters simultâneos dobram o
custo e tornam a verificação de limpeza ambígua.

---

## 7. Problemas comuns

### `cpu: <unknown>/10%` e o HPA nunca escala

O metrics-server não está pronto. No Minikube: `minikube addons enable
metrics-server`. No EKS: `./02-metrics-server.sh`. Nos dois casos, espere ~1
minuto após o componente ficar `Ready` — ele precisa coletar a primeira janela
de amostras antes de publicar qualquer valor.

### `ErrImageNeverPull` no Minikube

A imagem foi construída no daemon do host, não no da VM. O `deploy-minikube.sh`
resolve com `eval $(minikube docker-env)`, mas isso vale **só no shell atual**.
Se você abriu outro terminal, rode o comando de novo antes de construir.

### A imagem não executa no EKS (`exec format error`)

Imagem construída em máquina ARM (Apple Silicon) e executada em nodes x86_64.
O `00-build-push-ecr.sh` já força `--platform=linux/amd64`; se construir à mão,
não esqueça a flag.

### O Service fica com `EXTERNAL-IP: <pending>` para sempre

Veja os eventos: `kubectl describe svc python-web`. As causas usuais são
subnets sem a tag exigida pelo controlador, ou limite de balanceadores da conta
atingido. Em cluster criado pelo `eksctl` com a configuração deste repositório,
as tags já vêm corretas — se travar, quase sempre é limite de serviço.

### Pods ficam `Pending` com `Insufficient cpu`

Não há capacidade no node para mais réplicas. É um resultado legítimo e vale
como evidência: **o HPA escala Pods, não nodes**. Aumentar o número de Pods não
cria instâncias EC2 — isso exigiria Cluster Autoscaler ou Karpenter, que este
trabalho deliberadamente não usa.

### `DeleteConflict` ao apagar uma role IAM

A role ainda pertence a um *instance profile*. Ordem correta:

```bash
aws iam list-instance-profiles-for-role --role-name <ROLE>
aws iam remove-role-from-instance-profile --instance-profile-name <IP> --role-name <ROLE>
aws iam delete-instance-profile --instance-profile-name <IP>
aws iam delete-role --role-name <ROLE>
```

### `bad interpreter: /bin/bash^M`

Arquivo com quebras de linha do Windows. O `.gitattributes` do repositório
impede que isso volte a acontecer; para consertar uma cópia local:

```bash
sed -i 's/\r$//' script.sh
```

### O script parou no meio e não sei o que ficou de pé

```bash
aws eks list-clusters --region us-east-1
aws ec2 describe-instances --region us-east-1 \
  --filters Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[].InstanceId' --output text
aws elb describe-load-balancers --region us-east-1 \
  --query 'LoadBalancerDescriptions[].LoadBalancerName' --output text
```

O `./99-cleanup.sh` é idempotente: pode ser rodado quantas vezes for preciso,
e ignora o que já não existe.
