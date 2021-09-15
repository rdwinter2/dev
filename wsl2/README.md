# WSL 2

## get krew for plugins

kind create cluster --name kind --image kindest/node:v1.22.1@sha256:100b3558428386d1372591f8d62add85b900538d94db8e455b66ebaf05a3ca3a --config=./kind.yaml

export ADDRESS_PREFIX=$(docker network inspect kind | jq ".[0].IPAM.Config[0].Gateway" | sed -e 's/"//g' | awk -F. '{print $1 "." $2}')
echo $ADDRESS_PREFIX

kubectl apply -f coredns_configmap.yaml
kubectl rollout restart -n kube-system deployment coredns

kubectl cluster-info --context kind-kind

kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.10.2/manifests/namespace.yaml
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.10.2/manifests/metallb.yaml

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - $address_prefix.255.200-$address_prefix.255.250
EOF

docker-compose up -d -e ADDRESS_PREFIX


## Loki
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm upgrade --install loki grafana/loki-stack  --set grafana.enabled=true,prometheus.enabled=true,prometheus.alertmanager.persistentVolume.enabled=false,prometheus.server.persistentVolume.enabled=false
# kubectl patch svc loki-grafana -p '{"spec": {"type": "LoadBalancer"}}'
# kubectl get svc loki-grafana -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
kubectl get secret loki-grafana -o go-template='{{range $k,$v := .data}}{{printf "%s: " $k}}{{if not $v}}{{$v}}{{else}}{{$v | base64decode}}{{end}}{{"\n"}}{{end}}'

cat <<-EOF | kubectl apply -f -
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: loki-grafana
  namespace: default
spec:
  entryPoints:
  - web
  routes:
  - kind: Rule
    match: Host(\`loki-grafana.localhost\`)
    services:
    - name: loki-grafana
      namespace: default
      port: 80
EOF


