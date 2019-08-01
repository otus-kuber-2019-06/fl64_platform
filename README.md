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

## PR checklist:
 - [ ] Выставлен label с номером домашнего задания
