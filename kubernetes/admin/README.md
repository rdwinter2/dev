# Tanzu Administration 

Placeholder project for group administration tasks and general documentation.

## Table of Contents
<!--ts-->
   * [Tanzu Administration](#tanzu-administration)
      * [Table of Contents](#table-of-contents)
      * [Goals of Tanzu for developer experience](#goals-of-tanzu-for-developer-experience)
      * [Logging in](#logging-in)
      * [devspace](#devspace)
      * [<a href="https://docs.mattermost.com/install/install-kubernetes.html" rel="nofollow">Mattermost</a>](#mattermost)
      * [Prometheus](#prometheus)
      * [20210204](#20210204)

<!-- Added by: xadmin, at: Fri Feb  5 16:07:30 UTC 2021 -->

<!--te-->

   
```bash
kubectl create ns mysql-operator
kubectl apply -n mysql-operator -f https://raw.githubusercontent.com/mattermost/mattermost-operator/master/docs/mysql-operator/mysql-operator.yaml
kubectl create ns minio-operator
kubectl apply -n minio-operator -f https://raw.githubusercontent.com/mattermost/mattermost-operator/master/docs/minio-operator/minio-operator.yaml
kubectl create ns mattermost-operator
kubectl apply -n mattermost-operator -f https://raw.githubusercontent.com/mattermost/mattermost-operator/master/docs/mattermost-operator/mattermost-operator.yaml

cat <<-EOT > mattermost-installation.yml
apiVersion: mattermost.com/v1alpha1
kind: ClusterInstallation
metadata:
  name: mm-example-full
spec:
  size: 1000users
  ingressName: mattermost.example.web
  ingressAnnotations:
    kubernetes.io/ingress.class: nginx
  version: 5.14.0
  database:
    storageSize: 50Gi
  minio:
    storageSize: 50Gi
EOT
kubectl create ns mattermost
kubectl apply -n mattermost -f ./mattermost-installation.yml
kubectl -n mattermost get ingress

```

```bash
curl -sL https://github.com/operator-framework/operator-lifecycle-manager/releases/download/v0.17.0/install.sh | bash -s v0.17.0
kubectl create -f https://operatorhub.io/install/mattermost-operator.yaml
kubectl get csv -n operators

```

## Prometheus

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm search repo prometheus-community


helm show values prometheus-community/kube-prometheus-stack

cat <<EOF > kube-prom-stack-values.yaml
grafana:
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
      - name: 'default'
        orgId: 1
        folder: ''
        type: file
        disableDeletion: false
        editable: true
        options:
          path: /var/lib/grafana/dashboards/default
 
  dashboards:
    default:
      yugabytedb:
        url: https://raw.githubusercontent.com/yugabyte/yugabyte-db/master/cloud/grafana/YugabyteDB.json
EOF
kubectl create namespace monitoring
 
helm install prom prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values kube-prom-stack-values.yaml

kubectl get pods --namespace monitoring
```


## 20210204

```bash
# Port forward to the first istio-ingressgateway pod
alias igpf='kubectl -n istio-system port-forward $(kubectl -n istio-system get pods -listio=ingressgateway -o=jsonpath="{.items[0].metadata.name}") 15000'

# Get the http routes from the port-forwarded ingressgateway pod (requires jq)
alias iroutes='curl --silent http://localhost:15000/config_dump | jq '\''.configs.routes.dynamic_route_configs[].route_config.virtual_hosts[]| {name: .name, domains: .domains, route: .routes[].match.prefix}'\'''

# Get the logs of the first istio-ingressgateway pod
# Shows what happens with incoming requests and possible errors
alias igl='kubectl -n istio-system logs $(kubectl -n istio-system get pods -listio=ingressgateway -o=jsonpath="{.items[0].metadata.name}") --tail=300'

# Get the logs of the first istio-pilot pod
# Shows issues with configurations or connecting to the Envoy proxies
alias ipl='kubectl -n istio-system logs $(kubectl -n istio-system get pods -listio=pilot -o=jsonpath="{.items[0].metadata.name}") discovery --tail=300'


t=$(mktemp)
curl --silent http://localhost:15000/config_dump > $t
istioctl proxy-config routes --file $t
istioctl proxy-config listeners --file $t
istioctl proxy-config clusters --file $t
istioctl proxy-config bootstrap --file $t
istioctl proxy-config secret --file $t


kns() {
    namespace=$1
    kubectl config set-context --current --namespace=$1
}


kns istio-system
kubectl apply -f /opt/istio/samples/addons
```

```bash
cd tekton

kubectl create ns tekton-pipelines
kubectl label namespace tekton-pipelines istio-injection=enabled

curl -O https://storage.googleapis.com/tekton-releases/pipeline/previous/v0.20.1/release.yaml

kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/previous/v0.20.1/release.yaml

kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml


kubectl get pods -n tekton-pipelines

curl -O https://storage.googleapis.com/tekton-releases/dashboard/previous/v0.13.0/tekton-dashboard-release.yaml
kubectl apply --filename https://storage.googleapis.com/tekton-releases/dashboard/previous/v0.13.0/tekton-dashboard-release.yaml

kubectl get svc tekton-dashboard -n tekton-pipelines
kubectl port-forward -n tekton-pipelines --address=0.0.0.0 service/tekton-dashboard 80:9097 > /dev/null 2>&1 &

kubectl patch service tekton-dashboard -n tekton-pipelines -p '{"spec": {"type": "LoadBalancer"}}'

http://10.10.77.135:9097

kg crd | grep tekton | awk '{print $1}' | xargs -I % kubectl delete crd %


kubectl patch crd/gitrepositories.source.toolkit.fluxcd.io -p '{"metadata":{"finalizers":[]}}' --type=merge


devspace.sh

