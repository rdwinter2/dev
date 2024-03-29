#!/bin/bash
# To run
# curl -LsSf https://raw.githubusercontent.com/rdwinter2/dev/main/setup.sh | bash
echo "Running script... 🚀"
#sudo apt-key adv --keyserver keyring.debian.org --recv-keys 7EA0A9C3F273FCD8
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
sudo apt-get update -yqq
sudo apt-get install -yqq acl apt-transport-https bash-completion ca-certificates dnsutils gnupg-agent python3 python3-pip python3-jinja2 python3-yaml python3-cryptography software-properties-common wget jq jid build-essential gcc htop unzip zsh
sudo ln -s /usr/bin/python3 /usr/bin/python
ssh-keygen -o -a 100 -t ed25519 -f ~/.ssh/id_ed25519 -N "" -C "$(whoami)@$(hostname)"
# use copied key instead
cp -f ~/.secrets/id_ed25519* ~/.ssh
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
ssh-keyscan gitlab.com >> ~/.ssh/known_hosts
#cat <<-EO_CONFIG > ~/.ssh/conf
## Read more about SSH config files: https://linux.die.net/man/5/ssh_config
#Host gitlab.com
#    HostName gitlab.com
#    Port 22
#    User rdwinter2
#    IdentityFile /home/rdwinter2/.ssh/id_ed25519
#    #UserKnownHostsFile=/dev/null
#    CheckHostIP=no
#    StrictHostKeyChecking=accept-new
#    LogLevel ERROR
#EO_CONFIG
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
sudo apt-get update -yqq
sudo apt-get install -yqq docker-ce docker-ce-cli containerd.io
#cat <<-EOT > /etc/docker/daemon.json
#{
#    "dns": ["192.168.90.252"]
#}
#EOT
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
docker network create loki
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
docker volume create portainer-data

mkdir -p {/tmp/git-sync/coredns/,/tmp/git-sync/traefik/}
sudo chown root:root -R /tmp/git-sync
sudo chmod 777 -R /tmp/git-sync

$(~/dev/scripts/homebrew.sh 2>&1 | tee /tmp/homebrew.out | cat > /dev/null) &
pids[1]=$!
t=$(mktemp -d); pushd $t
# GitHub cli - gh
VERSION=$(curl -fsSL "https://api.github.com/repos/cli/cli/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/' | cut -c2-)
curl -fsSL https://github.com/cli/cli/releases/download/v${VERSION}/gh_${VERSION}_linux_amd64.tar.gz | tar -xzf -
sudo install --mode=755 --owner=root ./gh_${VERSION}_linux_amd64/bin/gh /usr/local/bin/
sudo cp -r ./gh_${VERSION}_linux_amd64/share/man/man1/* /usr/share/man/man1/
yes | rm -rf ./gh_${VERSION}_linux_amd64*
# GitLab cli - lab
VERSION=$(curl -fsSL "https://api.github.com/repos/zaquestion/lab/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/' | cut -c2-)
curl -fsSL "https://github.com/zaquestion/lab/releases/download/v${VERSION}/lab_${VERSION}_linux_amd64.tar.gz" | tar -xzf -
sudo install -m755 ./lab /usr/local/bin/lab
yes | rm -rf {LICENSE,README.md,lab}

## Flux v2
#curl -s https://toolkit.fluxcd.io/install.sh | sudo bash
VERSION=$(curl -fsSL "https://api.github.com/repos/fluxcd/flux2/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/' | cut -c2-)
curl -fsSL "https://github.com/fluxcd/flux2/releases/download/v${VERSION}/flux_${VERSION}_linux_amd64.tar.gz" | tar -xzf -
sudo install -m755 ./flux /usr/local/bin
rm -f ./flux
#
sudo mkdir -p /usr/java
curl -fsSL https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download/jdk-11.0.9.1%2B1/OpenJDK11U-jdk_x64_linux_hotspot_11.0.9.1_1.tar.gz | sudo tar xzf - -C /usr/java
# export PATH=$PWD/jdk-11.0.9.1+1/bin:$PATH
sudo curl -fsSL "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq '.tag_name' | sed 's/"//g')/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
octant_vers=$(curl -s https://api.github.com/repos/vmware-tanzu/octant/releases/latest | jq '.tag_name' | sed -e 's/"//g' -e 's/^v//g')
sudo curl -fsSL -O https://github.com/vmware-tanzu/octant/releases/download/v${octant_vers}/octant_${octant_vers}_Linux-64bit.deb
sudo apt-get install ./octant_${octant_vers}_Linux-64bit.deb
curl -fsSL -O "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install --mode=755 --owner=root ./kubectl /usr/local/bin
curl -fsSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
curl -fsSL https://github.com/jenkins-x/jx-cli/releases/download/$(curl -s https://api.github.com/repos/jenkins-x/jx-cli/releases/latest | jq '.tag_name' | sed 's/"//g')/jx-cli-linux-amd64.tar.gz | tar xzv
sudo install --mode=755 --owner=root ./jx /usr/local/bin
VERSION=$(curl -fsSL "https://api.github.com/repos/kubernetes-sigs/kind/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/' | cut -c2-)
curl -fsSL -o ./kind https://github.com/kubernetes-sigs/kind/releases/download/v${VERSION}/kind-linux-amd64
sudo install --mode=755 --owner=root ./kind /usr/local/bin
rm -f ./kind
VERSION=$(curl -fsSL "https://api.github.com/repos/derailed/k9s/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/' | cut -c2-)
curl -fsSL https://github.com/derailed/k9s/releases/download/v${VERSION}/k9s_Linux_x86_64.tar.gz | tar xzf -
sudo install --mode=755 --owner=root ./k9s /usr/local/bin
yes | rm -f {k9s,LICENSE,README.md}
sudo curl -fSL -o "/usr/local/bin/tk" "https://github.com/grafana/tanka/releases/download/v0.13.0/tk-linux-amd64"
sudo chmod a+x "/usr/local/bin/tk"
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
sudo install --mode=755 --owner=root ./kustomize /usr/local/bin
curl -fLo cs https://git.io/coursier-cli-"$(uname | tr LD ld)"; chmod +x cs; yes | ./cs setup
### Ansible
# pip install ansible
# or
sudo git clone https://github.com/ansible/ansible.git --recursive /opt/ansible

mkdir --parents ~/.ansible/.logins
echo "localhost ansible_connection=local" > ~/.ansible/ansible_hosts
cat <<-EOT >> ~/.ansible/ansible.cfg
[defaults]
jinja2_extensions = jinja2.ext.do,jinja2.ext.i18n
EOT
echo $( openssl rand -base64 27 ) > ~/.ansible/.vault_pass
chmod 700 ~/.ansible
chmod 700 ~/.ansible/.logins
chmod 600 ~/.ansible/.vault_pass
. ~/.bashrc
VERSION=$(curl -fsSL "https://api.github.com/repos/istio/istio/releases" | jq '.[].tag_name' | sed 's/"//g' | grep -v "\-alpha\|\-beta\|\-rc" | sort --version-sort | tail -1)
curl -fsSL https://github.com/istio/istio/releases/download/${VERSION}/istio-${VERSION}-linux-amd64.tar.gz | sudo tar -xzf - --directory /opt
sudo ln --symbolic --force --no-dereference /opt/istio-${VERSION} /opt/istio
sudo chmod o+rx /opt/istio /opt/istio/bin /opt/istio/tools
sudo chmod o+r /opt/istio/manifest.yaml
export PATH="$PATH:/opt/istio/bin"

newgrp docker
docker plugin install grafana/loki-docker-driver:latest --alias loki --grant-all-permissions

cat <<-EOT | kind create cluster --name dev --image kindest/node:v1.22.1@sha256:100b3558428386d1372591f8d62add85b900538d94db8e455b66ebaf05a3ca3a --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: false
  apiServerAddress: 127.0.0.1
  apiServerPort: 6443
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"
kubeadmConfigPatches:
- |
  kind: ClusterConfiguration
  metadata:
    name: config
  apiServer:
    extraArgs:
      "v": "4"
  controllerManager:
    extraArgs:
      "v": "4"
  scheduler:
    extraArgs:
      "v": "4"
  ---
  kind: InitConfiguration
  nodeRegistration:
    kubeletExtraArgs:
      "v": "4"
nodes:
 - role: control-plane
   kubeadmConfigPatches:
   - |
     kind: InitConfiguration
     nodeRegistration:
       kubeletExtraArgs:
         node-labels: "ingress-ready=true"
         authorization-mode: "AlwaysAllow"
 - role: worker
   kubeadmConfigPatches:
   - |
     kind: JoinConfiguration
     nodeRegistration:
       kubeletExtraArgs:
         node-labels: "ingress-ready=true"
         authorization-mode: "AlwaysAllow"
 - role: worker
   kubeadmConfigPatches:
   - |
     kind: JoinConfiguration
     nodeRegistration:
       kubeletExtraArgs:
         node-labels: "ingress-ready=true"
         authorization-mode: "AlwaysAllow"
 - role: worker
   kubeadmConfigPatches:
   - |
     kind: JoinConfiguration
     nodeRegistration:
       kubeletExtraArgs:
         node-labels: "ingress-ready=true"
         authorization-mode: "AlwaysAllow"
EOT
kubectl cluster-info --context kind-dev

export ADDRESS_PREFIX=$(docker network inspect kind | jq ".[0].IPAM.Config[0].Gateway" | sed -e 's/"//g' | awk -F. '{print $1 "." $2}')
echo $ADDRESS_PREFIX

cat coredns_configmap.yaml | sed "s/1.1.1.1/${ADDRESS_PREFIX}.255.252/" | kubectl apply -f -
kubectl rollout restart -n kube-system deployment coredns

. ~/.bashrc
. ~/.profile
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.10.3/manifests/namespace.yaml
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.10.3/manifests/metallb.yaml
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
      - $ADDRESS_PREFIX.255.150-$ADDRESS_PREFIX.255.250
EOF
# kubectl get all --all-namespaces
echo "===================================================================="
# kubectl get pods,serviceaccounts,daemonsets,deployments,roles,rolebindings -n metallb-system
echo "===================================================================="

## Install ISTIO
yes | istioctl install --set profile=demo
kubectl label namespace default istio-injection=enabled

export GITLAB_TOKEN=$(cat ~/.logins/gl)
export GITLAB_USER=$(whoami)
flux check --pre
flux bootstrap gitlab \
  --owner=${GITLAB_USER} \
  --repository=flux_gitops \
  --branch=main \
  --path=./cluster \
  --private \
  --personal
# git clone https://${GITLAB_TOKEN_NAME}:${GITLAB_TOKEN}@gitlab.com:rdwinter2/flux_gitops.git ~/flux_gitops
git clone git@gitlab.com:rdwinter2/flux_gitops.git

#helm repo add traefik https://helm.traefik.io/traefik
#helm repo update
#kubectl create ns traefik
#helm install --namespace=traefik traefik traefik/traefik
#cat <<- EOT | kubectl apply -f -
## dashboard.yaml
#apiVersion: traefik.containo.us/v1alpha1
#kind: IngressRoute
#metadata:
#  name: dashboard
#spec:
#  entryPoints:
#    - websecure
#  routes:
#    - match: Host(\`traefik.localhost\`) && (PathPrefix(\`/dashboard\`) || PathPrefix(\`/api\`))
#      kind: Rule
#      services:
#        - name: api@internal
#          kind: TraefikService
#EOT
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

# kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.2.0/aio/deploy/recommended.yaml
