### Teste do HPA utilizando Minikube

Este repositório contém um servidor web simples, implementado no arquivo `app.py`, que responde às requisições HTTP com uma página HTML estática. O servidor é utilizado para demonstrar o funcionamento do **Horizontal Pod Autoscaler (HPA)** do Kubernetes.

Para iniciar o ambiente e realizar o deploy da aplicação no Minikube, execute:

```bash
minikube start

./deploy-minikube.sh
```

O script configura o ambiente, constrói a imagem Docker e cria o Deployment, o Service e o HPA da aplicação.

Após a implantação, é possível testar o funcionamento do HPA utilizando o script de geração de carga:

```bash
./minikube-load-test.sh
```

Esse script gera carga sobre a aplicação e acompanha o comportamento dos Pods e do HPA durante o teste. Ao executá-lo, uma pasta com os resultados e logs da execução será criada automaticamente.

O teste pode permanecer em execução pelo tempo desejado. Para encerrá-lo, basta pressionar Enter no terminal em que o script estiver sendo executado.