#!/bin/bash

secrets/gcloud.sh 
# put in a kill switch (1 hour)
x=$(sleep 3600; yes | gcloud compute instances delete instance-1 --zone=us-central1-a --delete-disks=all)&
until gcloud compute instances describe instance-1 --zone=us-central1-a > /dev/null
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
sleep 5
# without string interpolation
RESULT=1
x=50
until [ $RESULT -eq 0 ] 
do 
date
ssh instance-1  'bash -s' <<'ENDSSH'
ls
ENDSSH
RESULT=$?
((x--))
echo "Trying " $x " more times..."
if [[ $x -eq 0 ]]; then exit 500; fi
sleep 1
done

ssh instance-1 'bash -s' <<'ENDSSH'
mkdir -p ~/.certs
mkdir -p ~/.secrets
mkdir -p ~/promtail
mkdir -p ~/.logins
ENDSSH
# with string interpolation
ssh instance-1 'bash -s' <<ENDSSH
cat <<ENDGH > ~/.logins/gh
$(ansible-vault view ~/.ansible/.logins/github_dev_token)
ENDGH
chmod 600 ~/.logins/gh
cat <<ENDGH > ~/.logins/gl
$(ansible-vault view ~/.ansible/.logins/gitlab_flux_token)
ENDGH
chmod 600 ~/.logins/gl
ENDSSH
scp ~/.secrets/* instance-1:~/.secrets
scp ~/.certs/*.crt instance-1:~/.certs
scp ~/.certs/intermediate* instance-1:~/.certs
scp secrets/promtail/* instance-1:~/promtail
scp ~/.gitconfig instance-1:~/.gitconfig
ssh instance-1 'bash -s' <<'ENDSSH'
curl -LsSf https://raw.githubusercontent.com/rdwinter2/dev/main/setup.sh | bash
# mv -f ~/promtail/* ~/dev/promtail
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
