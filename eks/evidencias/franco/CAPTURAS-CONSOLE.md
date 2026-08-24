# Capturas do console AWS — Implantação B

Complementam as evidências coletadas por `kubectl`. O número da conta AWS foi
mascarado (barra de URL, seletor de conta e ARNs) por o repositório ser público.

| Arquivo | O que mostra | Momento |
|---|---|---|
| `E6-console-eks-cluster.png` | Cluster `psi512-t1-eks` **Active**, Kubernetes 1.34, plataforma eks.31, criado há 33 min. Aba **Add-ons: 1** | Depois do teste de carga, antes da remoção do cluster |
| `E7-console-ec2-nodes.png` | Os 2 nodes `t3.medium` **Running**, 3/3 checks, em AZs distintas (`us-east-1f` e `us-east-1d`) | idem |
| `E9-console-lb-removido.png` | Lista de Load Balancers **vazia** | **Depois** da remoção do Service |
| `E9-console-pods-kube-system.png` | Apenas 6 Pods de sistema (`coredns` x2, `kube-proxy` x2, `metrics-server` x2). Nenhum `python-web` | **Depois** da remoção do Deployment |

## Ressalva sobre o momento das capturas

As duas últimas foram tiradas com a limpeza já em curso, então **não** documentam
o estado sob carga: registram o estado *após* a remoção da aplicação. Por isso
estão nomeadas `E9-*` (limpeza) e não `E4-*`/`E5-*`.

Isso não deixa lacuna de evidência: o Classic Load Balancer provisionado e as 5
réplicas distribuídas entre os dois nodes já estão documentados em
`E3-service-lb.txt`, `E5-distribuicao-nodes.txt` e `E4-navegador.png`.

`E9-console-pods-kube-system.png` corrobora um achado do trabalho: o
`metrics-server` roda como **add-on gerenciado do EKS** (2 réplicas em
`kube-system`, aba *Add-ons* com 1 item), instalado por padrão pelo `eksctl` —
e não pela aplicação manual do manifesto oficial, como descreve a documentação
da AWS citada no enunciado.
