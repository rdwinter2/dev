#!/bin/bash

secrets/gcloud.sh 
until gcloud compute instances describe instance-1 --zone=us-central1-a
do
  echo "waiting for instance-1 creation ..."
  sleep 1
done
EXTERNAL_IP=$(gcloud compute instances describe instance-1 --zone=us-central1-a | grep natIP | awk '{print $2}')
echo ${EXTERNAL_IP}
# If it doesn't already have the right IP 
export USR=rdwinter2
CONF=/c/Users/${USR}/.ssh/config && grep $EXTERNAL_IP $CONF || sed -i.bak$(date +%s) "0,/\s*HostName .*/s//    HostName ${EXTERNAL_IP}/" $CONF
CONF=/home/${USR}/.ssh/config && grep $EXTERNAL_IP $CONF || sed -i.bak$(date --iso-8601=seconds) "0,/\s*HostName .*/s//    HostName ${EXTERNAL_IP}/" $CONF

# without string interpolation
ssh instance-1 'bash -s' <<'ENDSSH'
mkdir -p ~/.certs
mkdir -p ~/.secrets
mkdir -p ~/promtail
ENDSSH
# with string interpolation
ssh instance-1 'bash -s' <<ENDSSH
mkdir -p ~/.logins
cat <<ENDGH > ~/.logins/gh
$(ansible-vault view ~/.ansible/.logins/github_dev_token)
ENDGH
chmod 600 ~/.logins/gh
ENDSSH
scp ~/.secrets/portainer_password instance-1:~/.secrets
scp ~/.certs/*.crt instance-1:~/.certs
scp ~/.certs/intermediateCA_password instance-1:~/.certs
scp ~/.certs/intermediate_ca.key instance-1:~/.certs
scp ~/promtail/* instance-1:~/promtail
ssh instance-1 'bash -s' <<'ENDSSH'
curl -LsSf https://raw.githubusercontent.com/rdwinter2/dev/main/setup.sh | bash
cp ~/.certs/intermediateCA_password ~/dev/secrets/password
cp ~/.certs/intermediate_ca.key ~/dev/secrets/intermediate_ca.key
cp ~/.certs/root_ca.crt ~/dev/certs/root_ca.crt
cp ~/.certs/intermediate_ca.crt ~/dev/certs/intermediate_ca.crt
sudo cp ~/dev/certs/root_ca.crt /usr/local/share/ca-certificates/root_ca.crt
sudo cp ~/dev/certs/intermediate_ca.crt /usr/local/share/ca-certificates/intermediate_ca.crt
sudo /usr/sbin/update-ca-certificates
newgrp docker
cd ~/dev
docker-compose -f ~/dev/docker-compose-git-sync.yml up -d
sleep 10
docker-compose  -f ~/dev/docker-compose.yml up -d 
docker logs -f traefik
ENDSSH
