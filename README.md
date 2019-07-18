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
