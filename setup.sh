#!/bin/bash
# To run 
# curl -LsSf https://raw.githubusercontent.com/rdwinter2/dev/main/setup.sh | bash
echo "Running script... 🚀"
sudo apt-get update
sudo apt-get install -y apt-transport-https bash-completion ca-certificates dnsutils gnupg-agent software-properties-common wget jq jid build-essential gcc htop zsh
ssh-keygen -o -a 100 -t ed25519 -f ~/.ssh/id_ed25519 -N "" -C "$(whoami)@$(hostname)"
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
#cat <<-EOT > /etc/docker/daemon.json
#{
#    "dns": ["192.168.90.252"]
#}
EOT
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $(whoami)
newgrp docker

git clone https://github.com/rdwinter2/dev.git
touch dev/logs/traefik.log
mkdir ~/.bashrc.d
cp dev/files/.bashrc.d/* ~/.bashrc.d
git clone https://github.com/magicmonty/bash-git-prompt.git ~/.bash-git-prompt --depth=1
cat <<-EOT >> ~/.bashrc
for file in ~/.bashrc.d/*.bashrc;
do
 . \$file
done
EOT
docker network create --gateway 192.168.90.1 --subnet 192.168.90.0/24 traefik
docker network create keycloak
docker network create mattermost
docker network create mongo
docker volume create step-ca
docker volume create traefik-acme
docker volume create nexus-data
docker volume create gitlab_config
docker volume create gitlab_logs
docker volume create gitlab_data
docker volume create gitlab-runner_conf
docker volume create keycloak_postgres_data
docker volume create mattermost_config
docker volume create mattermost_data
docker volume create mattermost_logs
docker volume create mattermost_plugins
docker volume create mattermost_client_plugins
docker volume create mattermost_postgresql_data
docker volume create mattermost_postgresql_dump
docker volume create mongo_data
docker volume create mongo_express_data
docker volume create nifi-logs
docker volume create nifi-conf
docker volume create nifi-database_repository
docker volume create nifi-flowfile_repository
docker volume create nifi-content_repository
docker volume create nifi-provenance_repository
docker volume create nifi-state

mkdir -p {/tmp/git-sync/coredns/,/tmp/git-sync/traefik/}
sudo chown root:root -R /tmp/git-sync
sudo chmod 777 -R /tmp/git-sync

$(~/dev/scripts/homebrew.sh 2>&1 | tee /tmp/homebrew.out | cat > /dev/null) &
pids[1]=$!
t=$(mktemp -d); pushd $t
GH_VERSION=`curl  "https://api.github.com/repos/cli/cli/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/' | cut -c2-`
curl -fsSL -O https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz
tar xvf ./gh_${GH_VERSION}_linux_amd64.tar.gz
sudo install --mode=755 --owner=root ./gh_${GH_VERSION}_linux_amd64/bin/gh /usr/local/bin/
sudo cp -r ./gh_${GH_VERSION}_linux_amd64/share/man/man1/* /usr/share/man/man1/
rm -rf ./gh_${GH_VERSION}_linux_amd64*
sudo mkdir -p /usr/java
curl -fsSL https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download/jdk-11.0.9.1%2B1/OpenJDK11U-jdk_x64_linux_hotspot_11.0.9.1_1.tar.gz | sudo tar xzf - -C /usr/java
# export PATH=$PWD/jdk-11.0.9.1+1/bin:$PATH
sudo curl -fsSL "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq '.tag_name' | sed 's/"//g')/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
octant_vers=0.17.0
sudo curl -fsSL -O https://github.com/vmware-tanzu/octant/releases/download/v${octant_vers}/octant_${octant_vers}_Linux-64bit.deb
sudo apt-get install ./octant_${octant_vers}_Linux-64bit.deb
curl -fsSL -O "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install --mode=755 --owner=root ./kubectl /usr/local/bin
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
curl -fsSL https://github.com/jenkins-x/jx-cli/releases/download/$(curl -s https://api.github.com/repos/jenkins-x/jx-cli/releases/latest | jq '.tag_name' | sed 's/"//g')/jx-cli-linux-amd64.tar.gz | tar xzv 
sudo install --mode=755 --owner=root ./jx /usr/local/bin
curl -fsSL -o ./kind https://kind.sigs.k8s.io/dl/v0.10.0/kind-linux-amd64
sudo install --mode=755 --owner=root ./kind /usr/local/bin
curl -fsSL https://github.com/derailed/k9s/releases/download/v0.24.2/k9s_Linux_x86_64.tar.gz | tar xzf - 
sudo install --mode=755 --owner=root ./k9s /usr/local/bin
sudo curl -fSL -o "/usr/local/bin/tk" "https://github.com/grafana/tanka/releases/download/v0.13.0/tk-linux-amd64"
sudo chmod a+x "/usr/local/bin/tk"
popd
pushd /opt
curl -fsSL https://istio.io/downloadIstio | sudo sh -
sudo mv istio-* istio
sudo chmod o+rx /opt/istio /opt/istio/bin /opt/istio/tools
sudo chmod o+r /opt/istio/manifest.yaml
export PATH="$PATH:/opt/istio/bin"
popd

newgrp docker
cat <<-EOT | kind create cluster --name dev --image kindest/node:v1.20.2@sha256:8f7ea6e7642c0da54f04a7ee10431549c0257315b3a634f6ef2fecaaedb19bab --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: control-plane
- role: control-plane
- role: worker
- role: worker
- role: worker
EOT
kubectl cluster-info --context kind-dev


#cat <<-EOT | kind create cluster --name production --config=-
#kind: Cluster
#apiVersion: kind.x-k8s.io/v1alpha4
#nodes:
#- role: control-plane
#  image: kindest/node:v1.20.0@sha256:b40ecf8bcb188f6a0d0f5d406089c48588b75edc112c6f635d26be5de1c89040
#  kubeadmConfigPatches:
#  - |
#    kind: InitConfiguration
#    nodeRegistration:
#      kubeletExtraArgs:
#        node-labels: "ingress-ready=true"
#  extraPortMappings:
#  - containerPort: 80
#    hostPort: 9080
#    protocol: TCP
#  - containerPort: 443
#    hostPort: 9443
#    protocol: TCP
#EOT
#kubectl cluster-info --context kind-production
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.4/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.4/manifests/metallb.yaml
# On first install only
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
export address_prefix=$(docker network inspect kind | jq ".[0].IPAM.Config[0].Gateway" | sed -e 's/"//g' | awk -F. '{print $1 "." $2}')
echo $address_prefix
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
      - $address_prefix.255.150-$address_prefix.255.250
EOF
# kubectl get all --all-namespaces
echo "===================================================================="
# kubectl get pods,serviceaccounts,daemonsets,deployments,roles,rolebindings -n metallb-system
echo "===================================================================="

helm repo add traefik https://helm.traefik.io/traefik
helm repo update
kubectl create ns traefik
helm install --namespace=traefik traefik traefik/traefik
cat <<- EOT | kubectl apply -f -
# dashboard.yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: dashboard
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(\`traefik.localhost\`) && (PathPrefix(\`/dashboard\`) || PathPrefix(\`/api\`))
      kind: Rule
      services:
        - name: api@internal
          kind: TraefikService
EOT
# curl -vik --resolve traefik.localhost:443:172.18.255.1 https://traefik.localhost/dashboard

# The workflow is:
# 1) make a registry (with certs for the registry). In our case we have several root certs that we can get from nexus with the curl command you previously showed
# 2) manually deploy a KinD server, with plugin mods to add the registry as a mirror (but it will be untrusted)
# 3) docker cp <certs> kind-control-plane:/usr/local/share/ca-certificates/
# 4) docker exec -it kind-control-plane update-ca-certificates
# 5) then deploy tkg, telling it to use the manually spun up KinD for the bootstrap

echo "wait for background processes"
# wait for all pids
for pid in ${pids[*]}; do
    wait $pid
done
cat /tmp/homebrew.out

echo "Run:: newgrp docker"
echo "Run:: . ~/.profile"
echo "Done. 👍"