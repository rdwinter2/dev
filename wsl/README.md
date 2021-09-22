# WSL 2

## get krew for plugins

```sh
scripts/generateCerts.sh
sudo cp ~/.certs/root_ca.crt /usr/local/share/ca-certificates/root_ca.crt
sudo cp ~/.certs/intermediate_ca.crt /usr/local/share/ca-certificates/intermediate_ca.crt
sudo /usr/sbin/update-ca-certificates
```

Then install the root_ca.crt and the client client.p12 in the Windows trust store.

```sh
kind create cluster --name kind --image kindest/node:v1.22.1@sha256:100b3558428386d1372591f8d62add85b900538d94db8e455b66ebaf05a3ca3a --config=./kind.yaml

export ADDRESS_PREFIX=$(docker network inspect kind | jq ".[0].IPAM.Config[0].Gateway" | sed -e 's/"//g' | awk -F. '{print $1 "." $2}')
echo $ADDRESS_PREFIX

cat coredns_configmap.yaml | sed "s/1.1.1.1/${ADDRESS_PREFIX}.255.252/" | kubectl apply -f -
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
      - $address_prefix.255.200-$address_prefix.255.240
EOF

istioctl install -y -f ../docker-desktop/kind-istio.yaml
kubectl label namespace default istio-injection=enabled


vol() {
  vol=$1
  docker volume ls | grep --quiet "local     ${vol}" || docker volume create ${vol}
}
for i in gitlab-runner_conf gitlab_config gitlab_data gitlab_logs nexus-data step-ca traefik-acme; do
  vol $i
done

# Delete and recreate docker volumes
for i in gitlab-runner_conf gitlab_config gitlab_data gitlab_logs nexus-data step-ca traefik-acme; do
  docker volume rm $i
  vol $i
done

# only modify file if necessary
# egrep -q "^ADDRESS_PREFIX=${ADDRESS_PREFIX}$" .env || gawk -i inplace "/^ADDRESS_PREFIX=/{gsub(/=.*$/, \"=${ADDRESS_PREFIX}\")};{print}" .env

docker-compose up -d -e ADDRESS_PREFIX


docker exec -it nexus cat /nexus-data/admin.password
```

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

## python-gitlab

```sh
sudo pip install --upgrade python-gitlab

cat <<-EOF | sudo tee /etc/python-gitlab.cfg > /dev/null
[global]
default = localhost-gitlab
ssl_verify = false
timeout = 5

[localhost-gitlab]
url = http://172.23.255.250
private_token = xdBzoMReUxtxFJ1N_yAp
api_version = 4

[gitlab-com]
url = https://gitlab.com


EOF
```

## Network Debugging

```sh
docker run -it --net container:traefik nicolaka/netshoot
```

## Install Ansible

sudo apt update
sudo apt upgrade --yes
sudo apt install --yes software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install --yes ansible


mkdir python-gitlab
git clone https://github.com/python-gitlab/python-gitlab.git
cd python-gitlab
tag=v2.10.1
git checkout $tag
docker build -t python-gitlab:$tag .
git checkout master

docker run -it --rm --net kind -e GITLAB_PRIVATE_TOKEN=xdBzoMReUxtxFJ1N_yAp -v /etc/python-gitlab.cfg:/python-gitlab.cfg:ro python-gitlab:$tag <command> ...


docker run -it --rm --net kind -e GITLAB_PRIVATE_TOKEN=xdBzoMReUxtxFJ1N_yAp -v /etc/python-gitlab.cfg:/python-gitlab.cfg:ro python-gitlab:$tag project list

docker run -it --rm --net kind -e GITLAB_PRIVATE_TOKEN=$(ansible-vault view ~/.ansible/.logins/gitlab.com) -v /etc/python-gitlab.cfg:/python-gitlab.cfg python:3.9.7 bash
pip install python-gitlab
cat <<-EOF > /etc/python-gitlab.cfg
[global]
default = gitlab
ssl_verify = true
timeout = 5

[gitlab]
url = https://gitlab.com
api_version = 4
EOF
gitlab project list
