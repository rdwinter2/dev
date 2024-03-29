# WSL 2

```
sudo su -
cat <<EOF >> /etc/wsl.conf
# Enable extra metadata options by default
[automount]
enabled = true
root = /mnt/
options = "metadata,umask=22,fmask=11"
mountFsTab = false

[network]
generateResolvConf = false
EOF
cat <<EOF > /etc/resolv.conf
# This file is no longer automatically generated by WSL. The following entry was added to /etc/wsl.conf:
# [network]
# generateResolvConf = false
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
```

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
EOF

sudo pip3 install -U Commitizen

curl -s https://raw.githubusercontent.com/zaquestion/lab/master/install.sh | sudo bash


## oh-my-zsh

runs less command with -R (repaint). You can disable this behavior by adding the following line at the end of your ~/.zshrc

unset LESS;

## Minikube on WSL with HyperV

Windows

Chocolatey

https://mudrii.medium.com/kubernetes-local-development-with-minikube-on-hyper-v-windows-10-75f52ad1ed42

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

choco upgrade chocolatey -y
choco install lxrunoffline -y


download https://lxrunoffline.apphb.com/download/Fedora/rawhide

LxRunOffline i -n Fedora -d D:\wsl\Fedora -r . -f C:\Users\<user>\Downloads\fedora-Rawhide.20210930-x86_64.tar.xz -s


download https://lxrunoffline.apphb.com/download/Debian/Bullseye

LxRunOffline i -n Debian-Bullseye -d D:\wsl\Debian-Bullseye -f C:\Users\rdwin\Downloads\rootfs.tar.xz -s
wsl -d Debian-Bullseye
apt update
apt-get install -y sudo locales
localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
apt upgrade
adduser rdwinter2
mkdir /etc/sudoers.d
cat <<EOF > /etc/sudoers.d/rdwinter2
rdwinter2 ALL=(ALL:ALL) NOPASSWD: ALL
EOF
LxRunOffline su -n Debian-Bullseye -v 1000


choco install kubernetes-cli -y
choco install minikube -y
choco install kind -y
minikube version
minikube update-check

minikube start --driver=hyperv --cpus=4 --memory=6144 --hyperv-virtual-switch="WSL"

minikube stop
Set-VMMemory minikube -DynamicMemoryEnabled $false
minikube start

minikube addons list
minikube addons enable heapster
minikube status
minikube service list
minikube dashboard
minikube dashboard --url
minikube ssh


kubectl config use-context minikube
kubectl config current-context
kubectl get po -n kube-system
kubectl get po — all-namespaces
kubectl get all — all-namespaces
kubectl api-versions | grep rbac
kubectl version
kubectl cluster-info
kubectl api-versions

kubectl run hello-minikube — image=k8s.gcr.io/echoserver:1.4 — port=8080
kubectl expose deployment hello-minikube — type=NodePort
kubectl get services
kubectl get deploy
kubectl get pod

minikube ip


```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
minikube start --driver=hyperv
minikube config set driver hyperv

minikube stop

Go into settings and "Enable Dynamic Memory"
"External Wired Switch"

minikube start --vm-driver hyperv --hyperv-virtual-switch "WSL"



Download latest stable docker CLI from https://download.docker.com/win/static/stable/x86_64/

Copy docker.exe to C:\Users\rdwin\AppData\Local\Microsoft\WindowsApps

WSL Ubuntu

```sh
sudo apt-get update
sudo apt-get upgrade
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce-cli


# https://magda.io/docs/installing-minikube.html

~/.local/bin/minikube
#!/bin/sh
/mnt/c/ProgramData/chocolatey/bin/minikube.exe $@

~/.local/bin/minikube-go
#!/bin/sh
eval $(minikube docker-env --shell=bash)
export DOCKER_CERT_PATH=$(wslpath -u "${DOCKER_CERT_PATH}")

Set-NetIPInterface -ifAlias "vEthernet (WSL)" -Forwarding Enabled
Set-NetIPInterface -ifAlias "vEthernet (Default Switch)" -Forwarding Enabled

Get-NetIPInterface | where {$_.InterfaceAlias -eq 'vEthernet (WSL)' -or $_.InterfaceAlias -eq 'vEthernet (K8s-Switch)'} | Set-NetIPInterface -Forwarding Enabled


#Create switch
New-VMSwitch –SwitchName “NAT” –SwitchType Internal –Verbose
# Get ifindex of new switch
Get-NetAdapter
#Create gateway
New-NetIPAddress –IPAddress 192.168.0.1 -PrefixLength 24 -InterfaceIndex 10 –Verbose
#Create NAT Network
New-NetNat –Name NATNetwork –InternalIPInterfaceAddressPrefix 192.168.1.0/24 –Verbose
#Change VMs to use new NAT switch
Get-VM | Get-VMNetworkAdapter | Connect-VMNetworkAdapter –SwitchName “NAT"


minikube delete --all --purge
minikube start --driver=hyperv --cpus=4 --memory=6144


Set-NetIPInterface -ifAlias "vEthernet (WSL)" -Forwarding Enabled
Set-NetIPInterface -ifAlias "vEthernet (Default Switch)" -Forwarding Enabled


Set-NetIPInterface -ifAlias "vEthernet (minikube)" -Forwarding Enabled

```


```powershell
& minikube -p minikube docker-env | Invoke-Expression
```

Python

https://www.python.org/ftp/python/3.9.7/python-3.9.7-amd64.exe

3.1.2. Removing the MAX_PATH Limitation

https://docs.python.org/3/using/windows.html

In the latest versions of Windows, this limitation can be expanded to approximately 32,000 characters. Your administrator will need to activate the “Enable Win32 long paths” group policy, or set LongPathsEnabled to 1 in the registry key HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem.



## Debian

sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

sudo mkdir /sys/fs/cgroup/systemd
sudo mount -t cgroup -o none,name=systemd cgroup /sys/fs/cgroup/systemd

cd /tmp
wget --content-disposition \
  "https://gist.githubusercontent.com/djfdyuruiry/6720faa3f9fc59bfdf6284ee1f41f950/raw/952347f805045ba0e6ef7868b18f4a9a8dd2e47a/install-sg.sh"


  rdwinter2@DESKTOP-72MKB01:/tmp$ cat install-sg.sh
#! /usr/bin/env bash
set -e

# change these if you want
UBUNTU_VERSION="20.04"
GENIE_VERSION="1.44"

GENIE_FILE="systemd-genie_${GENIE_VERSION}_amd64"
GENIE_FILE_PATH="/tmp/${GENIE_FILE}.deb"
GENIE_DIR_PATH="/tmp/${GENIE_FILE}"

function installDebPackage() {
  # install repackaged systemd-genie
  sudo dpkg -i "${GENIE_FILE_PATH}"

  rm -rf "${GENIE_FILE_PATH}"
}

function downloadDebPackage() {
  rm -f "${GENIE_FILE_PATH}"

  pushd /tmp

  wget --content-disposition \
    "https://github.com/arkane-systems/genie/releases/download/v${GENIE_VERSION}/systemd-genie_${GENIE_VERSION}_amd64.deb"

  popd
}

function installDependencies() {
  sudo apt-get update

  wget --content-disposition \
    "https://packages.microsoft.com/config/ubuntu/${UBUNTU_VERSION}/packages-microsoft-prod.deb"

  sudo dpkg -i packages-microsoft-prod.deb
  rm packages-microsoft-prod.deb

  sudo apt-get install apt-transport-https

  sudo apt-get update
  sudo apt-get install -y \
    daemonize \
    dotnet-runtime-5.0 \
    systemd-container

  sudo rm -f /usr/sbin/daemonize
  sudo ln -s /usr/bin/daemonize /usr/sbin/daemonize
}

function main() {
  installDependencies

  downloadDebPackage

  installDebPackage
}



https://arkane-systems.github.io/wsl-transdebian/

sudo -s
wget -O /etc/apt/trusted.gpg.d/wsl-transdebian.gpg https://arkane-systems.github.io/wsl-transdebian/apt/wsl-transdebian.gpg

chmod a+r /etc/apt/trusted.gpg.d/wsl-transdebian.gpg

cat << EOF > /etc/apt/sources.list.d/wsl-transdebian.list
deb https://arkane-systems.github.io/wsl-transdebian/apt/ $(lsb_release -cs) main
deb-src https://arkane-systems.github.io/wsl-transdebian/apt/ $(lsb_release -cs) main
EOF

apt update
apt install daemonize dbus dotnet-runtime-5.0 gawk libc6 libstdc++6 policykit-1 systemd systemd-container
apt install -y systemd-genie

curl -sSL https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
sudo apt-get install software-properties-common
sudo apt-add-repository https://packages.microsoft.com/debian/10/prod

sudo apt-get update


# WSL Debian

# Smallstep

wget https://dl.step.sm/gh-release/cli/docs-cli-install/v0.17.6/step-cli_0.17.6_amd64.deb
sudo dpkg -i step-cli_0.17.6_amd64.deb

wget https://dl.step.sm/gh-release/certificates/docs-ca-install/v0.17.4/step-ca_0.17.4_amd64.deb
sudo dpkg -i step-ca_0.17.4_amd64.deb


echo $(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1) > $HOME/.secrets/password
docker container rm step-ca
docker volume rm step-ca
docker volume create step-ca
docker run \
  --name step-ca \
  -p 8443:8443
  -v step-ca:/home/step \
  -v "$HOME/.secrets:/secrets/" \
  -v $HOME/.certs:/certs/ \
  -v /etc/ssl/certs:/etc/ssl/certs:ro \
  -v "$HOME/dev/scripts/entrypoint-step-ca.sh:/usr/local/bin/entrypoint-step-ca.sh" \
  -e DOCKER_STEPCA_INIT_NAME=smallstep \
  -e DOCKER_STEPCA_INIT_DNS_NAMES=localhost,$(hostname -f),${STEP_CA_IP},${STEP_CA_SERVICE_NAME},${STEP_CA_SERVICE_NAME}.${DOMAINNAME}
  --entrypoint /usr/local/bin/entrypoint-step-ca.sh \
  smallstep/step-ca:0.17.4 \


DNSNAMES=$1
CA_SERVER=$2
RESOLVER=$3
SUBORDINATE_CERT=$4
SUBORDINATE_KEY=$5
SUB_SIGNED_BY_CERT=$6

echo $(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1) > .secrets/password

step ca init --root=$HOME/.certs/intermediate_ca.crt --key=intermediate_ca.key --deployment-type=standalone --name=subordinate-ca --dns=localhost --dns=$(hostname -f) --provisioner=admin --address=:443 --password-file=.secrets/password

# get control over /etc/resolv.conf
cat <<EOF >> /etc/wsl.conf
[network]
generateResolvConf = false
EOF
# /etc/resolv.conf disappears after every reboot
# since we have genie start systemd via a Windows scheduled task
# use systemd to run a script to put /etc/resolv.conf back
cat <<EOF > /usr/local/bin/create_etc_resolv.sh
#!/bin/bash
cat <<EOF_resolv >> /etc/resolv.conf
nameserver 1.1.1.1
EOF_resolv
EOF
chmod a+x /usr/local/bin/create_etc_resolv.sh

cat <<EOF > /etc/systemd/system/create_etc_resolv.service
[Unit]
Description=Run once
After=local-fs.target
After=network.target

[Service]
ExecStart=/usr/local/bin/create_etc_resolv.sh
RemainAfterExit=true
Type=oneshot

[Install]
WantedBy=multi-user.target
EOF

genie -s
systemctl enable create_etc_resolv.service
systemctl start create_etc_resolv.service
