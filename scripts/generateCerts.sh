#!/usr/bin/env bash

step_tag=0.17.1
dir=$HOME/.certs
mkdir -p $dir
chmod 700 $dir
[[ -f $dir/rootCA_passwd ]] || \
echo $(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1) > $dir/rootCA_passwd
[[ -f $dir/root_ca.crt ]] || \
docker run -it --rm --user=$(id -u):$(id -g) -v $dir:/home/step smallstep/step-cli:${step_tag} bash -c " \
step certificate create 'Example Offline Root CA' \
  root_ca.crt root_ca.key \
  --profile=root-ca \
  --password-file=rootCA_passwd \
  --not-after=87600h \
"

[[ -f $dir/intermediateCA_passwd ]] || \
echo $(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1) > $dir/intermediateCA_passwd
[[ -f $dir/intermediate_ca.crt ]] || \
docker run -it --rm --user=$(id -u):$(id -g) -v $dir:/home/step smallstep/step-cli:${step_tag} bash -c " \
step certificate create 'Example Intermediate CA' \
  intermediate_ca.crt intermediate_ca.key \
  --profile=intermediate-ca \
  --ca=root_ca.crt \
  --ca-key=root_ca.key \
  --ca-password-file=rootCA_passwd \
  --password-file=intermediateCA_passwd \
  --not-after=8760h \
 # --no-password \
 # --insecure \
"

[[ -f $dir/example.com_wildcard.crt ]] || \
docker run -it --rm --user=$(id -u):$(id -g) -v $dir:/home/step smallstep/step-cli:${step_tag} bash -c " \
step certificate create 'example.com wildcard' \
  example.com_wildcard.crt example.com_wildcard.key \
  --profile=leaf \
  --ca=intermediate_ca.crt \
  --ca-key=intermediate_ca.key \
  --ca-password-file=intermediateCA_passwd \
  --san=*.example.com \
  --not-after 2160h \
  --no-password \
  --insecure \
"

[[ -f $dir/client_passwd ]] || \
echo $(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1) > $dir/client_passwd
[[ -f $dir/client.crt ]] || \
docker run -it --rm --user=$(id -u):$(id -g) -v $dir:/home/step smallstep/step-cli:${step_tag} bash -c " \
step certificate create 'Client Certificate' \
  client.crt client.key \
  --profile=leaf \
  --ca=intermediate_ca.crt \
  --ca-key=intermediate_ca.key \
  --ca-password-file=intermediateCA_passwd \
  --password-file=client_passwd \
  --not-after 2160h \
  --no-password \
  --insecure \
"

[[ -f $dir/client.p12 ]] || \
docker run -it --rm --user=$(id -u):$(id -g) -v $dir:/home/step smallstep/step-cli:${step_tag} bash -c " \
step certificate p12 client.p12 \
  client.crt client.key \
  --ca=intermediate_ca.crt \
  --password-file=client_passwd \
"
