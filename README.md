[![Gitpod ready-to-code](https://img.shields.io/badge/Gitpod-ready--to--code-blue?logo=gitpod)](https://gitpod.io/#https://github.com/rdwinter2/dev)

# dev
Development system with KinD. Can create a Google Compute Engine VM with the $300 free trial up to 24vCPU/128GB RAM as a custom spec.

```
curl -LsSf https://raw.githubusercontent.com/rdwinter2/dev/main/setup.sh | bash
```

## Table of Contents
<!--ts-->
   * [dev](#dev)
      * [Table of Contents](#table-of-contents)
      * [Instructions](#instructions)
      * [Setup](#setup)
      * [Binaries](#binaries)
      * [Docker images](#docker-images)
      * [On Windows](#on-windows)
      * [SSH Config](#ssh-config)
      * [Set GitLab root password](#set-gitlab-root-password)
      * [gcloud CLI](#gcloud-cli)
      * [Istio JWT](#istio-jwt)
   * [Create the traefik network](#create-the-traefik-network)
   * [docker network create traefik](#docker-network-create-traefik)
   * [Alternatively, you can specify the gateway and subnet to use](#alternatively-you-can-specify-the-gateway-and-subnet-to-use)
   * [docker network create --gateway 192.168.90.1 --subnet 192.168.90.0/24 traefik](#docker-network-create---gateway-192168901---subnet-19216890024-traefik)

<!-- Added by: rdwinter2, at: Fri Apr 23 08:00:51 CDT 2021 -->

<!--te-->

## Instructions

```bash
#####################
logfile=init_$(date --iso-8601=seconds).log
echo "Logging to logs/${logfile}"
./init.sh | tee logs/${logfile}
#####################

#########################  After configuring OpnSense
/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -File "flushdns.ps1"
#########################

##############################

gcloud compute instances describe instance-1

ssh instance-1


docker exec -it nexus bash -c "cat /nexus-data/admin.password; echo"

#####################
yes | gcloud compute instances delete instance-1 --zone=us-central1-a --delete-disks=all

# put in a kill switch
x=$(sleep 600; yes | gcloud compute instances delete instance-1 --zone=us-central1-a --delete-disks=all)&
#####################
```

## Setup

Create an offline X.509 Certificate Authority on Windows Subsystem for Linux (WSL). 

First, create a password for the root CA's key. Then create the root CA certificate and key, supplying the password when prompted.

```
mkdir -p $HOME/.certs; pushd $HOME/.certs
[[ -f rootCA_password ]] || echo $(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1) > rootCA_password
cat rootCA_password
docker run -it --rm -v $PWD:/home/step smallstep/step-cli:0.15.16 bash -c " \
step certificate create 'Offline Root CA' root_ca.crt root_ca.key --profile=root-ca \
"
```

Next, create the intermediate cert for use by the subordinate CA. 

```
[[ -f intermediateCA_password ]] || echo $(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1) > intermediateCA_password
docker run -it --rm --user=$(id -u):$(id -g) -v $PWD:/home/step smallstep/step-cli:0.15.16 bash -c " \
step certificate create 'Example Intermediate CA 1' \
    intermediate_ca.crt intermediate_ca.key \
    --profile=intermediate-ca --ca ./root_ca.crt \
    --ca-key <(step crypto key format --no-password --insecure --pem \
               --password-file <(cat rootCA_password) ./root_ca.key) \
    --no-password --insecure \
"
step certificate create 'Example Intermediate CA 2'  intermediate_ca2.crt intermediate_ca2.key --profile=intermediate-ca \
   --ca ./root_ca.crt \
   --ca-key <(step crypto key format --no-password --insecure --pem \
            --password-file <(cat rootCA_password) ./root_ca.key) \
   --san Example_Intermediate_CA_2
```

Create a wildcard certificate for "*.example.web".

```
docker run -it --rm -v $PWD:/home/step smallstep/step-cli:0.15.16 bash -c " \
step certificate create 'example.web wildcard' \
    example.web.crt example.web.key \
    --profile=leaf --ca ./root_ca.crt \
    --ca-key <(step crypto key format --no-password --insecure --pem \
               --password-file <(cat rootCA_password) ./root_ca.key) \
    --san *.example.web \
    --no-password --insecure --not-after 2160h \
"
```

Also, create a client certificate for connecting from Windows or WSL.

```
docker run -it --rm -v $PWD:/home/step smallstep/step-cli:0.15.16 bash -c " \
step certificate create client_crt \
    client_crt.crt client_crt.key \
    --profile=leaf --ca ./root_ca.crt \
    --ca-key <(step crypto key format --no-password --insecure --pem \
               --password-file <(cat rootCA_password) ./root_ca.key) \
    --no-password --insecure --not-after 2160h \
"
```

Convert the X.509 client certificate into a PFX and import it into Windows.

```
openssl pkcs12 -export -out client_crt.pfx -inkey client_crt.key -in client_crt.crt -certfile root_ca.crt

[[ -f client_crt_password ]] || echo $(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1) > client_crt_password
docker run -it --rm -v $PWD:/home/step smallstep/step-cli:0.15.16 bash -c " \
step certificate p12 client_crt.p12 \
    client_crt.crt client_crt.key \
    --ca root_ca.crt \
    --password-file client_crt_password \
"
```

Load `root_ca.crt` and `client_crt.p12` into the browser's trust store.

After creating a VM and running the setup.sh script, load the `root_ca.crt` and `intermediate_ca.crt` in the VM's trust store.

In WSL generate commands to execute on the VM. The file produced is stored in `secrets/certs.sh`.

```
scripts/get_certs.sh | tee secrets/certs.sh
```


```
############## EXECUTE ON WSL ###################
cat <<-EOF
############## EXECUTE ON VM ####################
cd ~/dev
cat <<-EOT > secrets/password
$(cat ~/.certs/intermediateCA_password)
EOT
cat <<-EOT > secrets/intermediate_ca.key
$(cat ~/.certs/intermediate_ca.key)
EOT
cat <<-EOT > certs/root_ca.crt
$(cat ~/.certs/root_ca.crt)
EOT
cat <<-EOT > certs/intermediate_ca.crt
$(cat ~/.certs/intermediate_ca.crt)
EOT
sudo cp certs/root_ca.crt /usr/local/share/ca-certificates/root_ca.crt
sudo cp certs/intermediate_ca.crt /usr/local/share/ca-certificates/intermediate_ca.crt
sudo /usr/sbin/update-ca-certificates
############## EXECUTE ON VM ####################
EOF
############## EXECUTE ON WSL ###################
```

In the home router "pfSense" set the Custom Options of the DNS Resolver to the IP of the GCP VM.

```
server:
local-zone: "example.web" redirect
local-data: "example.web 86400 IN A 192.168.1.54"
```

```
sudo apt install -y expect
wget https://github.com/smallstep/cli/releases/download/v0.15.3/step-cli_0.15.3_amd64.deb
sudo dpkg -i step-cli_0.15.3_amd64.deb


# [[ -f pwd_file ]] || echo $(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1) > pwd_file
docker run -it --rm -v $PWD:/home/step smallstep/step-cli:0.16.0-rc.8 bash -c " \
step certificate create 'Offline Root CA' root_ca.crt root_ca.key --profile=root-ca \
step certificate create 'Example Intermediate CA 1' \
    intermediate_ca.crt intermediate_ca.key \
    --profile=intermediate-ca --ca ./root_ca.crt \
    --ca-key <(step crypto key format --no-password --insecure --pem \
               --password-file <(cat pwd_file) ./root_ca.key) \
    --no-password --insecure \
step certificate create $(hostname) \
    $(hostname).crt $(hostname).key \
    --profile=leaf --ca ./root_ca.crt --ca-key ./root_ca.key \
    --no-password --insecure --not-after 2160h \
"
#  convert the X.509 into a PFX and import it into Windows
openssl pkcs12 -export -out cert.pfx -inkey private.key -in cert.crt -certfile CACert.crt

step certificate create $(hostname) $(hostname).crt $(hostname).key --profile=leaf --ca ./root_ca.crt --ca-key ./root_ca.key --ca-password-file pwd_file --password-file pwd_file2
step certificate create foo foo.crt foo.key --profile=leaf --ca ./root_ca.crt --ca-key ./root_ca.key --ca-password-file pwd_file --password-file pwd_file2

step certificate create opnsense opnsense.crt opnsense.key --profile=leaf --ca ./root_ca.crt --ca-key <(step crypto key format --no-password --insecure --pem --password-file <(cat rootCA_password) ./root_ca.key)     --no-password --insecure --not-after 2160h --san x.x.x.x --san opnsense.example.web
```

Create a VM on Google Compute Engine, or elsewhere. Choose *Debian GNU/Linux 10 (buster)* and *Allow HTTPS traffic*. You uan create a Google Compute Engine VM with upto the $300 free trial up to 24vCPU/128GB RAM as a custom spec.

Add your public ssh key to Compute Engine -> Metadata -> SSH Keys. Then configure VS Code *Remote-SSH*. Set the `.ssh/config` similar to"

```
Host <VM name>
    HostName <VM External IP>
    Port 22
    User <Username from ssh key>
    IdentityFile <path to>\.ssh\id_rsa
    UserKnownHostsFile=NUL
    CheckHostIP=no
    StrictHostKeyChecking=no
```

Then *Remote-SSH: Connect to Host...*. Install extnsions *Resource Monitor*, 

```bash
curl -LsSf https://gist.githubusercontent.com/rdwinter2/68809acd5e35f42c9319dddd316ff054/raw/d1d2da72f4924482bbbd0fb5d25bf4fcc7cdf246/debian_kind.sh | bash
newgrp docker
```

## Binaries

```
nifi
```

## Docker images

```
bitnami/openldap:2.4.55
sonatype/nexus3:3.28.1
gitlab/gitlab-ce:13.5.4-ce.0
gitlab/gitlab-runner:v13.5.0
library/traefik:v2.3.2
thomseddon/traefik-forward-auth:2.2.0
smallstep/step-ca:0.15.5
smallstep/step-cli:0.15.3
library/postgres:13.1
mattermost/mattermost-team-edition:release-5.29
jboss/keycloak:11.0.2
bitnami/zookeeper:3.6.2
coredns/coredns:1.8.0
library/caddy:2.2.1
prom/prometheus:v2.22.1
library/redis:6.0.9
library/mongo:4.0.21
linuxserver/code-server:version-v3.6.2

gcr.io/google-containers/cadvisor:v0.36.0
```

```
curl -vikL --resolve instance-1.example.web:443:35.188.31.180 https://instance-1.example.web/

docker run -it --rm --network=traefik busybox
docker run -it --rm --network=traefik --dns=192.168.90.252 -v /etc/ssl/certs:/etc/ssl/certs:ro smallstep/step-cli
step certificate inspect https://traefik.example.web
step certificate inspect https://nexus.example.web


docker exec -it nexus sh -c "cat /nexus-data/admin.password;echo"

```

## On Windows 

Create a ssh key \

```
ssh-keygen -t ed25519
```

If the External IP of the GCP VM changes:

1. Open PowerShell as an administrator and run `ipconfig /flushdns`.
2. Modify the wildcard DNS in OpnSense
3. Update the .ssh config file for VSCode.

## SSH Config 

On Windows

```
Host instance-1
    HostName <external_IP>
    Port 22
    User <username>
    IdentityFile C:\Users\<username>\.ssh\id_rsa
    UserKnownHostsFile=NUL
    CheckHostIP=no
    StrictHostKeyChecking=no
```

 On WSL


```
Host instance-1
    HostName <external_IP>
    Port 22
    User <username>
    IdentityFile /c/Users/<username>/.ssh/id_rsa
    UserKnownHostsFile=NUL
    CheckHostIP=no
    StrictHostKeyChecking=no
```

## Set GitLab root password

```bash
docker exec -i --tty=false gitlab sh <<-EOF 
gitlab-rails console -e production <<- EOT
user = User.where(id: 1).first
user.password = 'my_secret_pass'
user.password_confirmation = 'my_secret_pass'
user.save!
EOT
EOF
docker exec -it gitlab sh
gitlab-rails console -e production
user = User.where(id: 1).first
user.password = 'secret_pass'
user.password_confirmation = 'secret_pass'
user.save!
exit
exit
```

## gcloud CLI

```bash
gcloud auth login --no-launch-browser
gcloud config set project PROJECT_ID
gcloud compute disk-types list --filter="zone:( us-central1-a us-central1-b us-central1-c us-central1-f )"
gcloud compute zones describe us-central1-a --format="value(availableCpuPlatforms)"


# see file secrets/gcloud.sh for detailed command generated from GCP console
gcloud compute instances create instance-1 \
  --image-family debian-10 \
  --image-project debian-cloud \
  --boot-disk-type=pd-ssd \
  --boot-disk-size=256GB \
  --preemptible

if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))  
{  
  $arguments = "& '" +$myinvocation.mycommand.definition + "'"
  Start-Process powershell -Verb runAs -ArgumentList $arguments
  Break
}

docker run --rm httpd:2.4-alpine htpasswd -nbB admin "password" | cut -d ":" -f 2 | sed 's/\$/$$/g'

kns() { 
    namespace=$1
    kubectl config set-context --current --namespace=$1
}

```


## Istio JWT

curl host.domain -H "host: f.q.d.n"

https://www.youtube.com/watch?v=MoCFt2zaaVA

---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: "enable-mtls"
  namespace: "default"
spec:
  host: "*.local"
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL

---
apiVersion: "authentication.istio.io/v1alpha1"
kind: "Policy"
metadata:
  name: "jwt-example"
spec:
  targets:
  - name: hello
  peer:
  - mtls: {}
  origins:
  - jwt:
      issuer: "http-echo@http-echo.kubernetes.newtech.academy"
      jwsUri: "http://auth.kubernetes.newtech.academy/.well-known/jwks.json"
  principalBinding: USE_ORIGIN

---


curl url -H "host: f.q.d.n" -H "Authorization: Bearer $TOKEN"

###

.env.sample
WHOAMI_TAG=v1.5.0
WHOAMI_DIGEST=e6d0a6d995c167bd339fa8b9bb2f585acd9a6e505a6b3fb6afb5fcbd52bbefb8
HOST_NAME=localhost
DOMAINNAME=localdomain
REGISTRY=registry-1.docker.io

docker-compose.yml
version: "3.7"

########################### NETWORKS
# Create the traefik network
# docker network create traefik
# Alternatively, you can specify the gateway and subnet to use
# docker network create --gateway 192.168.90.1 --subnet 192.168.90.0/24 traefik

networks:
  traefik:
    external:
      name: traefik

########################### SERVICES
services:

  whoami:
    container_name: whoami
    hostname: whoami
    domainname: ${DOMAINNAME}
    image: ${REGISTRY}/containous/whoami:${WHOAMI_TAG}@sha256:${WHOAMI_DIGEST}
    restart: always
    networks:
      - traefik
    labels:
      traefik.enable: true
      traefik.http.routers.whoami.rule: Host(`${HOST_NAME}.${DOMAINNAME}`) && PathPrefix(`/whoami`) 
      traefik.http.routers.whoami.service: whoami
      traefik.http.routers.whoami.entrypoints: https
      traefik.http.routers.whoami.middlewares: whoami
      traefik.http.middlewares.whoami.stripPrefix.prefixes: /whoami
      traefik.http.routers.whoami.tls: true
      traefik.http.routers.whoami.tls.certResolver: step
      traefik.http.services.whoami.loadbalancer.server.port: 80
