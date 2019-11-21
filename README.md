# fl64_platform
fl64 Platform repository

# HomeWork 1
## Подготовка окружения
Необходимое окружение:
- virtualbox
- kubectl + autocompletion
- minicube
- k9s
Установка окружения осуществляется с использованием anible playbook ( https://github.com/fl64/fedora-ansible-bootstrap/tree/dev ). В частности для этого используются роли: vbox,k8s,zsh.

## Что было сделано
### Minikube

- Запуск minikube
```
minikube start
```
- Проверка текущей конфигурации
```
kubectl config view
```
![](https://i.imgur.com/QAC1FIP.png)
- Проверка подключения к кластеру
```
kubectl cluster-info
```

![](https://i.imgur.com/68Q5AX2.png)
- Получение списков дополнений для minikube `minikube addons list`
- Включение дополнения dashboard `minikube addons enable dashboard`
- Открыть dashboard в браузере `minikube dashboard`

### Inside minikube
```
minikube ssh
docker rm -f $(docker ps -a -q)
```
После удаления контейнеров, все они восстанавливаются спустя некоторое время.

### kubectl

```bash
# Показать все поды в NS **kube-system**
kubectl get pods -n kube-system
# Удалить системные контейнеры
kubectl delete pod --all -n kube-system
# Проверка, все ли ок с кластером?
kubectl get componentstatuses
#or
kubectl get cs
```
![](https://i.imgur.com/s803edG.png)
#### Задание
> Разберитесь почему все pod в namespace kube-system восстановились после удаления.

Поды:
- `kube-apiserver`
- `kube-scheduler`
- `kube-controller-manager`
- `etcd`
являются static-pods (https://kubernetes.io/docs/tasks/administer-cluster/static-pod/). Запускаются напряммую через сервис kubelet. Описание манфиестов подов находится в `/etc/kubernetes/manifests`.

- `сoredns-*` поды управляются через deployments контроллер который создает replicaset
- `kube-proxy` поды управляются через daemonset
Восстанавливаются средствами управляющими их контролеров
![](https://i.imgur.com/v7wNhTv.png)
### Docker image
```bash
# Сборка и пул образа docker
docker build -t fl64/otus-k8s-nginx .
docker pull fl64/otus-k8s-nginx
# ====
kubectl apply -f web-pod.yaml # Применение манифеста
kubectl get pod
kubectl get pod web -o yaml #получить манифест работающего пода
kubectl describe pod web #текущее состояние пода
kubectl get pods -w  #изменение стостояния подов
kubectl port-forward --address0.0.0.0 pod/web 8000:8000
```

## Как проверить ?
Сервис доступен по адресу http://localhost:8000

# HomeWork 2
## Что было сделано
Для задач в каталогах task0{1-3}, последовательно применены манифесты `\d{1,2}-.*\.yaml`:
```
kubectl create -f <filename.yaml>
```

## Как проверить
```
kubectl [-n ns] get serviceaccounts
kubectl [-n ns] get roles
kubectl get clusterroles
kubectl [-n ns] get rolebindings
kubectl get clusterrolebindings

kubectl [-n ns] get rolebindings

kubectl auth can-i <verb> <resources> --as <subject> [-n ns]
```

# HomeWork 3
## Что было сделано
- Для приложения были добавлены проверки: **readinessProbe** и **livenessProbe**.
- Создан манифест для развертывания приложения в виде Deployment
- Создан манифест сервиса
- Kube-proxy в Minikube был перенастроен для работы в режиме ipvs.
```
kubectl --namespace kube-system edit configmap/kube-proxy
kubectl --namespace kube-system delete pod --selector='k8s-app=kube-proxy'
```
Запуск миникуба: `minikube start  --extra-config=proxy.Mode=ipvs` - не помог, хотя явные отсылки есть в документации (minikube start  --extra-config=proxy.Mode=ipvs).
- Настроен для работы MetalLB
    - Для доступа к публикуемым адресам сервисов необходим был роут до них (Пример: `sudo route add 172.17.255.0/24 192.168.99.108`). Возникла проблема с тем что адреса не пингуются. Как оказалось в таблице маршрутизации выше стоял маршрут, созданный докер демоном, который перенавпрялял 172.17.0.0/17 на интерфейс docker0. Квик фикс: удалить маршрут до докера или выбрать альтернативную подсеть.
    - Выполнено задание со *. Настроен доступ на баллансировщик **coredns**.
- Настроен для работы Nginx-Ingress контроллер
    - Частично выполнено задание со * по пробросу dashboard. Вроде все пробрасывается, но экран пустой, WTF.
    - Выполнено задание по канареечному развертыванию с http заголовками. 
        - В процессе выполения канареечное разывертывание взлетело только с указанием имени конкретного хоста. Без него nginx-ingress ругался.
```
E0728 16:46:32.434479       8 controller.go:1258] cannot merge alternative backend test2-test-svc-8000 into hostname  that does not exist
```

## Как проверить
### Применение deployment
```bash
minikube start
cd kubernetes-networks
kubectl apply -f web-deploy.yaml
kubectl get deploy
kubectl get pods
kubectl describe deployment web

# Просмотр трассировок

kubectl get events --watch
kubespy trace deploy web
```

https://ealebed.github.io/posts/2018/%D0%B7%D0%BD%D0%B0%D0%BA%D0%BE%D0%BC%D1%81%D1%82%D0%B2%D0%BE-%D1%81-kubernetes-%D1%87%D0%B0%D1%81%D1%82%D1%8C-5-deployments/

**maxSurge** - необязательное поле, указывающее максимальное количество подов (Pods), которое может быть создано сверх желаемого количества подов (Pods), описанного в развертывании. Значение может быть абсолютным числом (например, 5) или процентом от желаемого количества подов (например, 10%). Значение этого параметра не может быть установлено в 0 и по умолчанию равно 25%.

**maxUnavailable** - необязательное поле, указывающее максимальное количество подов, которые могут быть недоступны в процессе обновления. Значение может быть абсолютным числом (например, 5) или процентом от желаемого количества подов (Pods) (например, 10%). Абсолютное число рассчитывается из процента путем округления. Значение этого параметра не может быть установлено в 0 и по умолчанию равно 25%.

### Настройка сервисов
```bash
kubectl apply -f web-svc-cip.yaml 
kubectl apply -f web-svc-lb.yaml
kubectl get services
```

### Настройка IPVS

```bash
kubectl --namespace kube-system edit configmap/kube-proxy
--> mode: "ipvs"
kubectl --namespace kube-system delete pod --selector='k8s-app=kube-proxy'

minikube ssh
toolbox
dnf install -y ipvsadm && dnf clean all
```

Пригодившиеся ссылки:
- https://residentsummer.github.io/posts/2018/08/21/minikube-ipvs/
- https://kubernetes.io/blog/2018/07/09/ipvs-based-in-cluster-load-balancing-deep-dive/
- https://kubernetes.io/docs/setup/learning-environment/minikube/ --> https://kubernetes.io/docs/setup/learning-environment/minikube/
- https://github.com/kubernetes/kubernetes/blob/master/pkg/proxy/ipvs/README.md

### MetalLB

```bash
kubectl apply -fhttps://raw.githubusercontent.com/google/metallb/v0.8.0/manifests/metallb.yaml
kubectl apply -f metallb-config.yaml
sudo route add 172.17.255.0/24 192.168.99.108
curl http://172.17.255.3
```

### Задание со * #1
```bash
kubectl apply -f coredns-svc-lb.yaml
```
**Проверка:**

```bash
dig @172.17.255.1 web-svc-lb.default.svc.cluster.local +short
```

### Ingress
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/mandatory.yaml

kubectl apply -f nginx-lb.yaml     
kubectl apply -f web-svc-headless.yaml
kubectl apply -f web-ingress.yaml 

kubectl get ingresses/web
kubectl describe ingresses/web
```

**Проверка:**
```bash
curl -k https://172.17.255.3/web 
```
![](https://i.imgur.com/52EXbMK.png)

### Задание со * #2
```bash
kubectl apply -f dash-svc-headless.yaml
kubectl apply -f dash-ingress.yaml
```

**Проверка**
curl -k http://172.17.255.3/dashboard
Ингресс вроде как работает, но непонятно куда копать. В браузере при переходе по ссылке отображается пустая страница с примерно аналогичным содержимым.
![](https://i.imgur.com/qnElSfU.png)

### Задание со * #3
```bash
kubectl apply -f canary-ns-and-pods.yaml
kubectl apply -f canary-services.yaml
kubectl apply -f canary-ingress.yaml
```

**Проверка**
```bash
curl --resolve "test.example.com:80:172.17.255.3" http://test.example.com/
curl --resolve "test.example.com:80:172.17.255.3" -H "canary: true" http://test.example.com/
```
![](https://i.imgur.com/CSvf2m6.png)

Без указания хоста почему-то не взлетело. В логах nginx-ingress было следующее:
```
E0728 16:46:32.434479       8 controller.go:1258] cannot merge alternative backend test2-test-svc-8000 into hostname  that does not exist
```

Пригодившиеся ссылки:
- https://www.elvinefendi.com/2018/11/25/canary-deployment-with-ingress-nginx.html
- https://medium.com/@domi.stoehr/canary-deployments-on-kubernetes-without-service-mesh-425b7e4cc862
- https://github.com/stoehdoi/canary-demo?source=post_page---------------------------

# HomeWork 4

## В процессе сделано:
 - Установлен kind, mc
 - Запущен под с minio + PVC
 - Предоставлен доступ к minio с использованием Service.
## Задание со *
- Учетные данные minio перенесены в secret и добавлены в манфест minio-secret.yaml
## Как запустить проект:
```bash
## run kind
kind create cluster
export KUBECONFIG="$(kind get kubeconfig-path --name="kind")"

## go to folder
cd kubernetes-volumes

kubectl apply -f minio-statefulset.yaml

kubectl get pvc
kubectl get statefulsets
kubectl get pods
kubectl get pvc
kubectl get pv

# service
kubectl apply -f minio-headless-service.yaml
kubectl get svc

# secrets

echo -n 'username' | base64
echo -n 'password' | base64
```
![](https://i.imgur.com/h2EtCYY.png)
kubectl apply -f minio-secret.yaml 

## Как проверить работоспособность:
 - Например, перейти по ссылке http://localhost:8080

# HomeWork 5

## В процессе сделано:
 - создана конфигурация кластера с поддержкой snapshots
 - создан pod с pvc
## Как запустить проект:
```bash
## run kind
kind create cluster --config kubernetes-storage/cluster/cluster.yaml
export KUBECONFIG="$(kind get kubeconfig-path --name="kind")"

## go to folder
cd kubernetes-storage/hw

kubectl apply -f 01-csi-storage-class.yml  
kubectl apply -f 02-csi-pvc.yml  
kubectl apply -f 03-csi-pod-with-pv.yml

kubectl get pvc
kubectl get pv
```

## Как проверить работоспособность:
```bash
kubectl exec storage-pod -- /bin/bash -c 'echo data > /data/data'
kubectl exec storage-pod -- /bin/bash -c 'cat /data/data'

### Create snapshot
cat <<EOF | kubectl apply -f -
apiVersion: snapshot.storage.k8s.io/v1alpha1
kind: VolumeSnapshot
metadata:
  name: storage-pvc-snapshot
spec:
  snapshotClassName: csi-hostpath-snapclass
  source:
    name: storage-pvc
    kind: PersistentVolumeClaim
EOF

### Cleanup
kubectl delete pod storage-pod
kubectl delete pvc storage-pvc

### Restore PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: storage-pvc
spec:
  storageClassName: csi-hostpath-sc
  dataSource:
    name: storage-pvc-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

### Restore pod
kubectl apply -f 03-csi-pod-with-pv.yml
### Check
kubectl exec storage-pod -- /bin/bash -c 'cat /data/data'
```

# HomeWork 6

## В процессе сделано:
 - Установлен kubectl debug plugin
 - Решена проблема с запуском strace
 - Установлен и настроен iptables-tailer


## Процесс
### Strace debug
~/.kube/debug-conf
```
agentPort: 10027

agentless: false
agentPodNamespace: default
agentPodNamePrefix: debug-agent-pod
agentImage: aylei/debug-agent:latest

debugAgentDaemonset: debug-agent
debugAgentNamespace: kube-system
portForward: true
image: nicolaka/netshoot:latest
command:
- '/bin/bash'
- '-l'
```

```bash
#Установим под их первой домашки
kubectl apply -f ../kubernetes-intro/web-pod.yaml 

#Установим агента
kubectl apply -f https://raw.githubusercontent.com/aylei/kubectl-debug/master/scripts/agent_daemonset.yml -n kube-system
```

В поде запускам `strace -c -p1`
![](https://i.imgur.com/AGm1Arx.png)

Изучение репы разработчика показывает, что в агенте нехватает "SYS_PTRACE", "SYS_ADMIN". Смотрим daemon-set по ссылке, но там версия 0.0.1. Меняем ее на latest. И запускаем.
`kubectl apply -f strace/agent_daemonset.yml -n kube-system`
![](https://i.imgur.com/twplnOr.png)

### iptables-tailer

```
git clone https://github.com/piontec/netperf-operator
kubectl apply -f ./deploy/crd.yaml
kubectl apply -f ./deploy/rbac.yaml
kubectl apply -f ./deploy/operator.yaml

kubectl apply -f ./deploy/cr.yaml
kubectl describe netperf.app.example.com/example
```

![](https://i.imgur.com/UGHrATN.png)
Добавляем политику
`kubectl apply -f https://raw.githubusercontent.com/express42/otus-platform-snippets/master/Module-03/Debugging/netperf-calico-policy.yaml`
Цепляемся к ноде
`gcloud compute ssh gke-standard-cluster-1-default-pool-72de6c40-b94j`
Смотрим логи 
`journalctl -k | grep calico`
В логах беда, пакеты откидываются, ааа че делать то.
![](https://i.imgur.com/HRsLZBR.png)
Кароч, ставим **iptables-tailer**
```
kubectl apply -f ./kit/kit-clusterrole.yaml
kubectl apply -f ./kit/kit-serviceaccount.yaml
kubectl apply -f ./kit/kit-clusterrolebinding.yaml
kubectl apply -f ./kit/netperf-calico-policy.yaml
kubectl apply -f ./kit/iptables-tailer.yaml
```

Удаляем \ запускаем тесты
```
kubectl delete netperfs.app.example.com --all
kubectl apply -f ./deploy/cr.yaml
kubectl describe netperf.app.example.com/example

kubectl describe pod --selector=app=netperf-operator
```
![](https://i.imgur.com/9JQqVwi.png)

# Homework 7

 - [x] Основное ДЗ
 - [ ] Задание со *

## В процессе сделано:
 - Создан CRD с MySQL
 - Создан контроллер и запакован в docker образ

## Как запустить
#Создаем CRD + CR
```
kubectl apply -f ./deploy/crd.yml 
kubectl apply -f ./deploy/cr.yml 
```

#Cмотрим результат
```
kubectl get crd
kubectl get mysqls.otus.homework
kubectl describe mysqls.otus.homework mysql-instance
```

#Собираем контейнер и пулим его в докерхаб
```
docker build . -t fl64/mysql-operator:v0.1
docker pull fl64/mysql-operator:v0.1
```

#Применяем манифесты
```
kubectl apply -f ./deploy/service-account.yml
kubectl apply -f ./deploy/ClusterRole.yml
kubectl apply -f ./deploy/ClusterRoleBinding.yml
kubectl apply -f ./deploy/deploy-operator.yml
```

## Как проверить

#Заполняем данные
```
export MYSQLPOD=$(kubectl get pods -l app=mysql-instance -o jsonpath="{.items[*].metadata.name}")
kubectl exec -it $MYSQLPOD -- mysql -u root -potuspassword -e "CREATE TABLE test ( id smallint unsigned not null auto_increment, name varchar(20) not null, constraint pk_example primary key (id) );" otus-database
kubectl exec -it $MYSQLPOD -- mysql -potuspassword -e "INSERT INTO test ( id, name ) VALUES ( null, 'some data' );" otus-database
kubectl exec -it $MYSQLPOD -- mysql -potuspassword -e "INSERT INTO test ( id, name ) VALUES ( null, 'some data-2' );" otus-database
```

#Проверяем
```
kubectl exec -it $MYSQLPOD -- mysql -potuspassword -e "select * from test;" otus-database
```
![](https://i.imgur.com/Ux2h0Mc.png)
```
kubectl delete mysqls.otus.homework mysql-instance

kubectl get jobs
```
![](https://i.imgur.com/sCUg2lJ.png)

```
kubectl apply -f ./deploy/cr.yml 
export MYSQLPOD=$(kubectl get pods -l app=mysql-instance -o jsonpath="{.items[*].metadata.name}")
kubectl exec -it $MYSQLPOD -- mysql -potuspassword -e "select * from test;" otus-database

kubectl get jobs
```
![](https://i.imgur.com/54AoPhF.png)
![](https://i.imgur.com/IoNRwar.png)

## Удаляемся

#Для удаления используем:
```
kubectl delete mysqls.otus.homework mysql-instance
```

#Удаление данных после локальных тестов
```
kubectl delete mysqls.otus.homework mysql-instance
kubectl delete deployments.apps mysql-instance
kubectl delete pvc mysql-instance-pvc 
kubectl delete pv mysql-instance-pv
kubectl delete svc mysql-instance
```

# HomeWork 10

## В процессе сделано:
 - Установка с ипользованием Helm2 + tiller
 - Установка с ипользованием Helm2 + helm-tiller
 - Helm3
 - jsonnet
 - kastomize



## Процесс

### Tiller
```
kubectl apply -f kubernetes-templating/cert-manager/01-tiller-rb.yml
helm init --service-account=tiller
helm version
```

### Ingress
```
helm upgrade --install nginx-ingress stable/nginx-ingress --wait --namespace=nginx-ingress --version=1.11.1
```

### Certmanager
```
kubectl apply -f kubernetes-templating/cert-manager/02-tiller-cert-manager-rb.yml
helm init --tiller-namespace cert-manager --service-account tiller-cert-manager
```

### Add certmanager rpo

```
helm repo add jetstack https://charts.jetstack.io

kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.9/deploy/manifests/00-crds.yaml
kubectl label namespace cert-manager certmanager.k8s.io/disable-validation="true"

helm upgrade --install cert-manager jetstack/cert-manager --wait --namespace=cert-manager --version=0.9.0 --tiller-namespace cert-manager
-->> ERR
#cleanup
helm delete --purge cert-manager --tiller-namespace cert-manager
#correct helm
helm upgrade --install cert-manager jetstack/cert-manager --wait --namespace=cert-manager --version=0.9.0 --tiller-namespace cert-manager --atomic
ERR

```
 user@default   ~/g/moe/f/kubernetes-templating     kubernetes-templating   1  helm upgrade --install cert-manager jetstack/cert-manager --wait --namespace=cert-manager --version=0.9.0 --tiller-namespace cert-manager --atomic
Release "cert-manager" does not exist. Installing it now.
INSTALL FAILED
PURGING CHART
Error: release cert-manager failed: clusterroles.rbac.authorization.k8s.io is forbidden: User "system:serviceaccount:cert-manager:tiller-cert-manager" cannot create resource "clusterroles" in API group "rbac.authorization.k8s.io" at the cluster scope
Successfully purged a chart!
Error: release cert-manager failed: clusterroles.rbac.authorization.k8s.io is forbidden: User "system:serviceaccount:cert-manager:tiller-cert-manager" cannot create resource "clusterroles" in API group "rbac.authorization.k8s.io" at the cluster scope
```

How to fix:
https://docs.cert-manager.io/en/latest/reference/clusterissuers.html

Инициализируем helm с сервисным аккаунтом tiller - helm init --service-account=tiller
Деплоем cert-manager - helm upgrade --install cert-manager jetstack/cert-manager --wait --namespace=cert-manager --version=0.9.0 --atomic

```

### Cartmuseum

```
kubectl get service -n nginx-ingress

helm plugin install https://github.com/rimusz/helm-tiller

helm tiller run helm upgrade --install chartmuseum stable/chartmuseum --wait --namespace=chartmuseum --version=2.3.2 -f chartmuseum/values.yml

helm list
helm tiller run helm list

helm delete --purge chartmuseum   

export HELM_TILLER_STORAGE=configmap

helm upgrade --install chartmuseum stable/chartmuseum --wait --namespace=chartmuseum --version=2.3.2 -f kubernetes-templating/chartmuseum/values.yaml

```

### Harbor + helm3
```
helm3 upgrade --install harbor harbor/harbor --wait \
--namespace=harbor \
--version=1.1.2 \
-f kubernetes-templating/harbor/values.yaml
```

### Socks shop
```
helm upgrade --install socks-shop kubernetes-templating/socks-shop --wait --atomic

```

### kubecfg
```
kubecfg show services.jsonnet
kubecfg update services.jsonnet
```

### Kustomize
```
kubectl apply -k kubernetes-templating/kustomize/overlays/socks-shop-prod
```

# Homework 11

### Настрйока tiller
```bash
kubectl apply -f tiller-sa.yml 
helm init --service-account=tiller 
```
### Установка consul + Vault
```bash
#Conusl
helm install --name=consul consul-helm
#Vault
helm install --name=vault vault-helm
helm status vault
```
**Output**
```
LAST DEPLOYED: Mon Nov  4 13:01:13 2019
NAMESPACE: default
STATUS: DEPLOYED

RESOURCES:
==> v1/ConfigMap
NAME          DATA  AGE
vault-config  1     9s

==> v1/Pod(related)
NAME     READY  STATUS             RESTARTS  AGE
vault-0  0/1    Running            0         8s
vault-1  0/1    ContainerCreating  0         8s
vault-2  0/1    ContainerCreating  0         8s

==> v1/Service
NAME      TYPE       CLUSTER-IP   EXTERNAL-IP  PORT(S)            AGE
vault     ClusterIP  10.12.3.71   <none>       8200/TCP,8201/TCP  8s
vault-ui  ClusterIP  10.12.12.87  <none>       8200/TCP           8s

==> v1/ServiceAccount
NAME   SECRETS  AGE
vault  1        9s

==> v1/StatefulSet
NAME   READY  AGE
vault  0/3    8s

==> v1beta1/PodDisruptionBudget
NAME   MIN AVAILABLE  MAX UNAVAILABLE  ALLOWED DISRUPTIONS  AGE
vault  N/A            1                0                    9s

```

```bash
kubectl exec -it vault-0 -- vault operator init --key-shares=1 --key-threshold=1 `
```
**output**

```
Unseal Key 1: f+PXoLYxKyuDhWQEsOy1AJFY/I4NGPGIJhGdMWyUiRY=

Initial Root Token: s.kNuybZmQgRRD6iM22ymtmD8z

```

```bash
kubectl exec -it vault-0 -- vault status`
```
**output**
```
Key                Value
---                -----
Seal Type          shamir
Initialized        true
Sealed             true
Total Shares       1
Threshold          1
Unseal Progress    0/1
Unseal Nonce       n/a
Version            1.2.2
HA Enabled         true
command terminated with exit code 2
```

```bash
kubectl exec -it vault-0 -- vault operator unseal 'f+PXoLYxKyuDhWQEsOy1AJFY/I4NGPGIJhGdMWyUiRY='
kubectl exec -it vault-1 -- vault operator unseal 'f+PXoLYxKyuDhWQEsOy1AJFY/I4NGPGIJhGdMWyUiRY='
kubectl exec -it vault-2 -- vault operator unseal 'f+PXoLYxKyuDhWQEsOy1AJFY/I4NGPGIJhGdMWyUiRY='


helm status vault
```
**output**
```
LAST DEPLOYED: Mon Nov  4 13:01:13 2019
NAMESPACE: default
STATUS: DEPLOYED

RESOURCES:
==> v1/ConfigMap
NAME          DATA  AGE
vault-config  1     3m44s

==> v1/Pod(related)
NAME     READY  STATUS   RESTARTS  AGE
vault-0  1/1    Running  0         3m43s
vault-1  1/1    Running  0         3m43s
vault-2  1/1    Running  0         3m43s

==> v1/Service
NAME      TYPE       CLUSTER-IP   EXTERNAL-IP  PORT(S)            AGE
vault     ClusterIP  10.12.3.71   <none>       8200/TCP,8201/TCP  3m43s
vault-ui  ClusterIP  10.12.12.87  <none>       8200/TCP           3m43s

==> v1/ServiceAccount
NAME   SECRETS  AGE
vault  1        3m44s

==> v1/StatefulSet
NAME   READY  AGE
vault  3/3    3m43s

==> v1beta1/PodDisruptionBudget
NAME   MIN AVAILABLE  MAX UNAVAILABLE  ALLOWED DISRUPTIONS  AGE
vault  N/A  
```

```bash
kubectl exec -it vault-0 --  vault login
```
**output**
```
Token (will be hidden): 
Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                  Value
---                  -----
token                s.kNuybZmQgRRD6iM22ymtmD8z
token_accessor       y06xxK4Rk8UihK0ERXO0usX9
token_duration       ∞
token_renewable      false
token_policies       ["root"]
identity_policies    []
policies             ["root"]
```

```bash
kubectl exec -it vault-0 --  vault auth list
```

**output**
```
Path      Type     Accessor               Description
----      ----     --------               -----------
token/    token    auth_token_ca0ff04b    token based credentials

```

```bash
kubectl exec -it vault-0 -- vault secrets enable --path=otus kv
kubectl exec -it vault-0 -- vault secrets list --detailed
```

**output**
```
Path          Plugin       Accessor              Default TTL    Max TTL    Force No Cache    Replication    Seal Wrap    Options    Description                                                UUID
----          ------       --------              -----------    -------    --------------    -----------    ---------    -------    -----------                                                ----
cubbyhole/    cubbyhole    cubbyhole_8910bb65    n/a            n/a        false             local          false        map[]      per-token private secret storage                           8738dc97-1ae1-bea8-50fd-0293526c95c8
identity/     identity     identity_5510e59e     system         system     false             replicated     false        map[]      identity store                                             acc14566-219b-c5e2-d654-977d98393dea
otus/         kv           kv_1f284987           system         system     false             replicated     false        map[]      n/a                                                        2a6501d0-4d39-0dda-5ca2-471e7cec2e86
sys/          system       system_c52bcb34       n/a            n/a        false             replicated     false        map[]      system endpoints used for control, policy and debugging    f8d111d8-6fe4-a319-c65b-de414fd40d18

```

```bash
kubectl exec -it vault-0 -- vault kv put otus/otus-ro/config username='otus'password='asajkjkahs'
kubectl exec -it vault-0 -- vault kv put otus/otus-rw/config username='otus'password='asajkjkahs'
kubectl exec -it vault-0 -- vault read otus/otus-ro/config
```

**output**
```
Key                 Value
---                 -----
refresh_interval    768h
username            otuspassword=asajkjkahs
```

```bash
kubectl exec -it vault-0 -- vault kv get otus/otus-rw/config
```

**output**
```
====== Data ======
Key         Value
---         -----
username    otuspassword=asajkjkahs
```

```bash
kubectl exec -it vault-0 -- vault auth enable kubernetes
kubectl exec -it vault-0 --  vault auth list
```

**output**
```
Path           Type          Accessor                    Description
----           ----          --------                    -----------
kubernetes/    kubernetes    auth_kubernetes_5ce9ebc5    n/a
token/         token         auth_token_ca0ff04b         token based credentials
```

```bash
kubectl create serviceaccount vault-auth
kubectl apply -f vault-auth-service-account.yml

export VAULT_SA_NAME=$(kubectl get sa vault-auth -o jsonpath="{.secrets[*]['name']}")
export SA_JWT_TOKEN=$(kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data.token}" |base64 --decode; echo)
export SA_CA_CRT=$(kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data['ca\.crt']}" |base64 --decode; echo)
export K8S_HOST=$(more ~/.kube/config | grep server |awk '/http/ {print $NF}')
```

**sed ’s/\x1b\[[0-9;]*m//g’ - убирает цвета :)**

```bash
kubectl exec -it vault-0 -- vault write auth/kubernetes/config token_reviewer_jwt="$SA_JWT_TOKEN" kubernetes_host="$K8S_HOST" kubernetes_ca_cert="$SA_CA_CRT"

kubectl cp otus-policy.hcl vault-0:./tmp
kubectl exec -it vault-0 -- vault policy write otus-policy /tmp/otus-policy.hcl
kubectl exec -it vault-0 -- vault write auth/kubernetes/role/otus  bound_service_account_names=vault-auth bound_service_account_namespaces=default policies=otus-policy  ttl=24h

kubectl run --generator=run-pod/v1 tmp --rm -i --tty --serviceaccount=vault-auth --image alpine:3.7 apk add curl jq && sh

kubectl run --generator=run-pod/v1 tmp --rm -i --tty --serviceaccount=vault-auth --image alpine:3.7 sh
VAULT_ADDR=http://vault:8200
KUBE_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
curl --request POST  --data '{"jwt": "'$KUBE_TOKEN'", "role": "otus"}' $VAULT_ADDR/v1/auth/kubernetes/login | jq
```
**output**
```json
{
  "request_id": "0fb0db3f-0765-33b2-67e6-910a2c851484",
  "lease_id": "",
  "renewable": false,
  "lease_duration": 0,
  "data": null,
  "wrap_info": null,
  "warnings": null,
  "auth": {
    "client_token": "s.Wk7mjFZBc9ss6q1n9eVZvc1x",
    "accessor": "rzxrGyJNmpRnsOvebDOdI25m",
    "policies": [
      "default",
      "otus-policy"
    ],
    "token_policies": [
      "default",
      "otus-policy"
    ],
    "metadata": {
      "role": "otus",
      "service_account_name": "vault-auth",
      "service_account_namespace": "default",
      "service_account_secret_name": "vault-auth-token-tfhqr",
      "service_account_uid": "13f717f6-feeb-11e9-a539-42010a800028"
    },
    "lease_duration": 86400,
    "renewable": true,
    "entity_id": "60ef27fe-0661-f2a6-f61f-f150e3cb51ef",
    "token_type": "service",
    "orphan": true
  }
}

```

```bash
TOKEN=$(curl -k -s --request POST  --data '{"jwt": "'$KUBE_TOKEN'", "role": "test"}' $VAULT_ADDR/v1/auth/kubernetes/login | jq '.auth.client_token' | awk -F\" '{print $2}')


curl --header "X-Vault-Token:${TOKEN}" $VAULT_ADDR/v1/otus/otus-ro/config
```
**output**
```json
{"request_id":"d09a931d-717e-1aee-3901-8092518a241d","lease_id":"","renewable":false,"lease_duration":2764800,"data":{"username":"otuspassword=asajkjkahs"},"wrap_info":null,"warnings":null,"auth":null}
```
curl --header "X-Vault-Token:${TOKEN}" $VAULT_ADDR/v1/otus/otus-rw/config
**output**
```
{"request_id":"af3fffd4-4742-2bb6-2de1-db197c597f5e","lease_id":"","renewable":false,"lease_duration":2764800,"data":{"username":"otuspassword=asajkjkahs"},"wrap_info":null,"warnings":null,"auth":null}
```

```bash
curl --request POST --data '{"bar": "baz"}'   --header "X-Vault-Token:${TOKEN}" $VAULT_ADDR/v1/otus/otus-ro/config
curl --request POST --data '{"bar": "baz"}'   --header "X-Vault-Token:${TOKEN}" $VAULT_ADDR/v1/otus/otus-rw/config
curl --request POST --data '{"bar": "baz"}'   --header "X-Vault-Token:${TOKEN}" $VAULT_ADDR/v1/otus/otus-rw/config1
```
**секрет config1 новый, потому успешно создался, для обновления config в политику (capabilities) необходимо доьбавить update**


## Use case использования авторизациичерез куберчерез кубе

```bash
cd vault-guides/identity/vault-agent-k8s-demo

kubectl create configmap example-vault-agent-config --from-file=./configs-k8s/
kubectl get configmap example-vault-agent-config -o yaml
kubectl apply -f example-k8s-spec.yml --record

kubectl exec -it vault-agent-example --container nginx-container sh
```
**index.html**
```
<html>
    <body>
    <p>Some secrets:</p>
    <ul>
    <li><pre>username: otus</pre></li>
    <li><pre>password: asajkjkahs</pre></li>
    </ul>

    </body>
</html>
```

## CA
Включимм УЦ
```bash
kubectl exec -it vault-0 -- vault secrets enable pki 
kubectl exec -it vault-0 -- vault secrets tune -max-lease-ttl=87600h pki 
kubectl exec -it vault-0 -- vault write -field=certificate pki/root/generate/internal common_name="exmaple.ru"  ttl=87600h > CA_cert.crt

kubectl exec -it vault-0 -- vault write pki/config/urls issuing_certificates="http://vault:8200/v1/pki/ca" crl_distribution_points="http://vault:8200/v1/pki/crl"

kubectl exec -it vault-0 -- vault secrets enable --path=pki_int pki
kubectl exec -it vault-0 -- vault secrets tune -max-lease-ttl=87600h pki_int
kubectl exec -it vault-0 -- vault write -format=json pki_int/intermediate/generate/internal common_name="example.ru Intermediate Authority" | jq -r '.data.csr' > pki_intermediate.csr

kubectl cp pki_intermediate.csr vault-0:./tmp
kubectl exec -it vault-0 -- vault write -format=json pki/root/sign-intermediate csr=@/tmp/pki_intermediate.csr format=pem_bundle ttl="43800h" |  jq -r '.data.certificate' > intermediate.cert.pem
kubectl cp intermediate.cert.pem vault-0:./tmp
kubectl exec -it vault-0 -- vault write pki_int/intermediate/set-signed certificate=@/tmp/intermediate.cert.pem

kubectl exec -it vault-0 -- vault write pki_int/roles/example-dot-ru   allowed_domains="example.ru" allow_subdomains=true   max_ttl="720h"

kubectl exec -it vault-0 -- vault write pki_int/issue/example-dot-ru common_name="gitlab.example.ru" ttl="24h"
```
**output**
```
Key                 Value
---                 -----
ca_chain            [-----BEGIN CERTIFICATE-----
MIIDnDCCAoSgAwIBAgIUH9yYJ5FFNCEB+CXdx8wIzw7kpxowDQYJKoZIhvcNAQEL
BQAwFTETMBEGA1UEAxMKZXhtYXBsZS5ydTAeFw0xOTExMDQxMTQyNDVaFw0yNDEx
MDIxMTQzMTVaMCwxKjAoBgNVBAMTIWV4YW1wbGUucnUgSW50ZXJtZWRpYXRlIEF1
dGhvcml0eTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALIK/G3NYb9j
8wtbMY5ZKiaC3Zlq/EL37VG7ua1NUX3rOroNRuz0qJXDU7SpG/44WPYXTRbBV/QY
BbK06yAN7DfMW3OeBxOzghS0JOrvbKFT4tdmga7GRSihGZkr7yIu7R4Z16kQ4KEw
80X2P+l7QNKlE9KKYs+7P7B5N46a+xTRLotFOFFiIGIbXNcUDm9LGTrREaBOmuCj
oDMPpAWYiz12IKyjVBX3TMhjDxmgzZSGExBHrZ2rD8+ZLvM3edtTrMCjWBQC93zU
0ZJlwaaUuuTgtuuY4XG09ziHIqr+juCBGkorxdqyI+aMjw/WjCqEClpFMn8Mv1na
Ydf8g+1xY60CAwEAAaOBzDCByTAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUw
AwEB/zAdBgNVHQ4EFgQUrnZi7efNMJfJpFA8rPQkJucNEXIwHwYDVR0jBBgwFoAU
9ujgMJnM6oqTqWZojqALHOjF9WEwNwYIKwYBBQUHAQEEKzApMCcGCCsGAQUFBzAC
hhtodHRwOi8vdmF1bHQ6ODIwMC92MS9wa2kvY2EwLQYDVR0fBCYwJDAioCCgHoYc
aHR0cDovL3ZhdWx0OjgyMDAvdjEvcGtpL2NybDANBgkqhkiG9w0BAQsFAAOCAQEA
b1eg+b3LNlsSzxotFehYaXIhjBcvoLpT9LSTpPp5Hp6LWYyZ2jxvA63AGCB5NR3O
2Aq/mg15m6SPU7eakpARQMdpdqe0JK1z8Liy+rhMlBUuG2AoJt+NIP8YtUtDu/5/
opc9kK+B1r1mmvCUiN0L17pkxPhnAHQpn49vU/UNydl84A9LMVdbdB7l4LU2b0SB
/HHs3lE9zKUcmHaao+r6YM7lxypj7vj7eXjD5Sipsz2VDkWIn8I2CaFsliSguQ55
R2fKaJ8XdQI8ZWAgM2EBX/KJ7jap+cZNIotHmE2WapunDfoXP21Z9pCeFdFVcq+S
CMGV/QbSyM+0K39GkZzJgg==
-----END CERTIFICATE-----]
certificate         -----BEGIN CERTIFICATE-----
MIIDZzCCAk+gAwIBAgIUVagKcrUw7Ar82G/4+i0GwHjRAdcwDQYJKoZIhvcNAQEL
BQAwLDEqMCgGA1UEAxMhZXhhbXBsZS5ydSBJbnRlcm1lZGlhdGUgQXV0aG9yaXR5
MB4XDTE5MTEwNDExNTE1N1oXDTE5MTEwNTExNTIyN1owHDEaMBgGA1UEAxMRZ2l0
bGFiLmV4YW1wbGUucnUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDC
oZ8rzqWDkVCVzjpDpqr10L9D0PtXoy+2EfgWV+NOUze+LXPx9oHV3YjdF8Ghh6jo
kkUvXx7QfFjghiIEZv9QMB5U6yC+YrfRNY+zoYwIU1D+0WEgWr0d14Ti1yo7Sm1m
UeS18vbQYYMNrO5p9D5SueD3Al0I6Impj6jhB4HAlfAnlfD/+rOAQ09ZQvkv13zc
K4q+h2rf5dXpLUfX9Mdecbg2FO/rotzbLEbeKbGUVOOAswHf69lK6qX1gegFYSjl
oW8asR8r/EfhqjXIcRzFOBR+zRhKW+6ELVEgv11SaEvpQn3glalteF1vdH7vo5OE
xUhPvf4tpQj7HA9Q8xqVAgMBAAGjgZAwgY0wDgYDVR0PAQH/BAQDAgOoMB0GA1Ud
JQQWMBQGCCsGAQUFBwMBBggrBgEFBQcDAjAdBgNVHQ4EFgQUuErTG5Hxqe7mntov
KEwcBlpqiV0wHwYDVR0jBBgwFoAUrnZi7efNMJfJpFA8rPQkJucNEXIwHAYDVR0R
BBUwE4IRZ2l0bGFiLmV4YW1wbGUucnUwDQYJKoZIhvcNAQELBQADggEBAABL0SPo
wQEc2+nFGCroumJbHnj8FWPIebwfjVGR/1wOxZSbc8lPrum2Lfw4ht8XW7ye20SV
K3YqIunh86e1PuoljJaRyNOR9HH2cD9M1PLWs4QIbxym/fgwMAY6VOEE/YI4wwaN
2JUi9i3wgAcj5znlPPTHzjKuVPmHsWBS4CdvtCed4cBBtnQLbPsbv+sGwYWWdDDM
WDVG5rQ6vsfxElQ/9c8cS5RRNIblQELfJS/VrYUsIZ0TEGR0WbwX/oX0znI0kScz
5dYNrnPshDq5a1X1OrhlD3COBHUjh05WZJLNKY02uVkH6ASoe9i+2rP1TbicBczp
0cDEFdE/mGXPfk4=
-----END CERTIFICATE-----
expiration          1572954747
issuing_ca          -----BEGIN CERTIFICATE-----
MIIDnDCCAoSgAwIBAgIUH9yYJ5FFNCEB+CXdx8wIzw7kpxowDQYJKoZIhvcNAQEL
BQAwFTETMBEGA1UEAxMKZXhtYXBsZS5ydTAeFw0xOTExMDQxMTQyNDVaFw0yNDEx
MDIxMTQzMTVaMCwxKjAoBgNVBAMTIWV4YW1wbGUucnUgSW50ZXJtZWRpYXRlIEF1
dGhvcml0eTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALIK/G3NYb9j
8wtbMY5ZKiaC3Zlq/EL37VG7ua1NUX3rOroNRuz0qJXDU7SpG/44WPYXTRbBV/QY
BbK06yAN7DfMW3OeBxOzghS0JOrvbKFT4tdmga7GRSihGZkr7yIu7R4Z16kQ4KEw
80X2P+l7QNKlE9KKYs+7P7B5N46a+xTRLotFOFFiIGIbXNcUDm9LGTrREaBOmuCj
oDMPpAWYiz12IKyjVBX3TMhjDxmgzZSGExBHrZ2rD8+ZLvM3edtTrMCjWBQC93zU
0ZJlwaaUuuTgtuuY4XG09ziHIqr+juCBGkorxdqyI+aMjw/WjCqEClpFMn8Mv1na
Ydf8g+1xY60CAwEAAaOBzDCByTAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUw
AwEB/zAdBgNVHQ4EFgQUrnZi7efNMJfJpFA8rPQkJucNEXIwHwYDVR0jBBgwFoAU
9ujgMJnM6oqTqWZojqALHOjF9WEwNwYIKwYBBQUHAQEEKzApMCcGCCsGAQUFBzAC
hhtodHRwOi8vdmF1bHQ6ODIwMC92MS9wa2kvY2EwLQYDVR0fBCYwJDAioCCgHoYc
aHR0cDovL3ZhdWx0OjgyMDAvdjEvcGtpL2NybDANBgkqhkiG9w0BAQsFAAOCAQEA
b1eg+b3LNlsSzxotFehYaXIhjBcvoLpT9LSTpPp5Hp6LWYyZ2jxvA63AGCB5NR3O
2Aq/mg15m6SPU7eakpARQMdpdqe0JK1z8Liy+rhMlBUuG2AoJt+NIP8YtUtDu/5/
opc9kK+B1r1mmvCUiN0L17pkxPhnAHQpn49vU/UNydl84A9LMVdbdB7l4LU2b0SB
/HHs3lE9zKUcmHaao+r6YM7lxypj7vj7eXjD5Sipsz2VDkWIn8I2CaFsliSguQ55
R2fKaJ8XdQI8ZWAgM2EBX/KJ7jap+cZNIotHmE2WapunDfoXP21Z9pCeFdFVcq+S
CMGV/QbSyM+0K39GkZzJgg==
-----END CERTIFICATE-----
private_key         -----BEGIN RSA PRIVATE KEY-----
MIIEpgIBAAKCAQEAwqGfK86lg5FQlc46Q6aq9dC/Q9D7V6MvthH4FlfjTlM3vi1z
8faB1d2I3RfBoYeo6JJFL18e0HxY4IYiBGb/UDAeVOsgvmK30TWPs6GMCFNQ/tFh
IFq9HdeE4tcqO0ptZlHktfL20GGDDazuafQ+Urng9wJdCOiJqY+o4QeBwJXwJ5Xw
//qzgENPWUL5L9d83CuKvodq3+XV6S1H1/THXnG4NhTv66Lc2yxG3imxlFTjgLMB
3+vZSuql9YHoBWEo5aFvGrEfK/xH4ao1yHEcxTgUfs0YSlvuhC1RIL9dUmhL6UJ9
4JWpbXhdb3R+76OThMVIT73+LaUI+xwPUPMalQIDAQABAoIBAQC39ft0dIWMrbT1
Y08+0jGU1hFyD/0BAIUAGkvbEocOaSmu31dPxCdD9Xh/QQ0LmCXWbSpndAi0FlQL
I7zTXGbFbDW/Hd59FOGZJH8G0hKBa/6KW2zqH9nQcvxvS9/m2po8s/rw3wzaONCe
BG30R58AoiA4WEuHOAOl+NsuluHVHD0/d1Ew8JNThkRuDMnIdyBm/nk0KOPToB88
QYlhfJ2oHtj7WKLYrKxJ4yJPIGj0ePxRlzUOGUf2we13ZUKEy+4Wt7ooMf4yhcjf
tpeJ7KWC7bRblAh+pra1jm6T9OcMJJHoo9ME70VDuRTp0cV6LScWbBpDjEGlw4Np
vLYcV9MBAoGBAOD70aNr+Qo+dLmrTJW1r7ZVjkAwLKyVcF39wPY1aJBMPeWRD+x3
0RuLC51WkRGkcB/gmLG/mLOlrvixedOlLwCvsT8XjI28WM6dk8sVOuffV6UDFL28
AegcjFWeqN1NdX0ydu0Lj720oh+TQ5fjp8QRfVsnUaAuvUz3o/JrQU5ZAoGBAN12
mb/W+6jG+X/frs9N2S7pJOlGxC2xCMgLSrRYkB63wkhvlaJ5zjrja/XcWzHrUrFD
6TipzdDGWoGeR6ZviwyXxy/Y58YE7j8FVn6JAdasM/yFX2ZZH/qVf3C8j3ZC/bnd
BjxjaYcieik3pXMMb4XF7E71BJBO0/3Ri3znwL6dAoGBAN5SufTd67ldwob/aay/
X6W0od94O41IF0QqT5Z9bJi7XqcOVEf+ltq66n1OYAipEEvP69QqW0GbRm5nItYs
c2ggNez83l3pc3CpcrTKg+1CXR+pDcP4l4HBREQPhxs5QhK33aGdPSvf5h2BrtfX
lZ9BETkUf6rkxRfb11zk9CHxAoGBAISTmG0YxOT/4KLlhF/Dyc1kct1XqN91iL1A
zULzdat99EeqzRhL9OKZ/KpddRaIOqO19Osf8/8Uj1/jIh+HzOUIA40oO2/2ya1e
g64SVNBvnFuCeF7r4dIAJx+VMgjpB715jF8gYC8uu5TrJBegjS63EsUdttKw7gWX
qPpoPqGdAoGBAI3UMrb6IfVKor4CR5s2JnZ7eHFIr/eAevoS/CVTYiUb2ntlATHI
ANXm0HLkmhhlcfA9uwK18907uPZHEQix2dVnXSPpZOEVXMGB1jn1ZFDnJi61gz9L
Bpi37/Hc2z80z/7hrjwmks3A28Sad9I0SR5W1nCh1fZsrFPWRMplN2Cu
-----END RSA PRIVATE KEY-----
private_key_type    rsa
serial_number       55:a8:0a:72:b5:30:ec:0a:fc:d8:6f:f8:fa:2d:06:c0:78:d1:01:d7
```

```bash
kubectl exec -it vault-0 -- vault write pki_int/revoke serial_number="55:a8:0a:72:b5:30:ec:0a:fc:d8:6f:f8:fa:2d:06:c0:78:d1:01:d7"
```
**output**
```
Key                        Value
---                        -----
revocation_time            1572868413
revocation_time_rfc3339    2019-11-04T11:53:33.127582887Z
```
