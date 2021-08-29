#!/bin/bash

mkdir -p ~/.zshrc.d
r=$(git rev-parse --show-toplevel)
for i in $(find ${r}/.zshrc.d -type f); do
  [[ -f ~/.zshrc.d/${i##*/} ]] || cp $i ~/.zshrc.d/${i##*/}
done

grep -qxF '# Added by git@github.com:rdwinter2/dev.git' ~/.zshrc || \
cat <<-EOF >> ~/.zshrc

# Added by git@github.com:rdwinter2/dev.git
## begin
#source /opt/zsh-git-prompt/zshrc.sh
#PROMPT='%B%m%~%b$(git_super_status) %# '

function kubectl() { echo "+ kubectl \$@">&2; command kubectl \$@; }
for file in ~/.zshrc.d/*.zshrc;
do
 source \$file
done
source /opt/ansible/hacking/env-setup -q
export PATH=\$PATH:/opt/ansible/bin
export ANSIBLE_INVENTORY=~/.ansible/ansible_hosts
export ANSIBLE_CONFIG=~/.ansible/ansible.cfg
export ANSIBLE_VAULT_PASSWORD_FILE=~/.ansible/.vault_pass
export EDITOR=vi
## end
EOF

[[ -f ~/.ssh/id_ed25519 ]] || ssh-keygen -o -a 100 -t ed25519 -f ~/.ssh/id_ed25519 -N "" -C "$(whoami)@$(hostname)"
[[ -f ~/.ssh/id_rsa ]] || ssh-keygen -o -t rsa -f ~/.ssh/id_rsa -N "" -C "$(whoami)@$(hostname)"

curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
sudo apt-get update -yqq
sudo apt-get install -yqq apt-transport-https bash-completion ca-certificates dnsutils gnupg gnupg-agent python-jinja2 python-yaml python-crypto software-properties-common wget jq jid build-essential gcc htop unzip
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

[[ -d /opt/ansible ]] || sudo git clone https://github.com/ansible/ansible.git --recursive /opt/ansible

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

# Informative git prompt for zsh
# [[ -d /opt/zsh-git-prompt ]] || sudo git clone https://github.com/olivierverdier/zsh-git-prompt.git /opt/zsh-git-prompt

# Install gcloud CLI
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
sudo apt-get update -yqq && sudo apt-get install -yqq google-cloud-sdk

r=$(git rev-parse --show-toplevel)
${r}/scripts/generateCerts.sh

sudo cp ~/.certs/root_ca.crt /usr/local/share/ca-certificates/root_ca.crt
sudo cp ~/.certs/intermediate_ca.crt /usr/local/share/ca-certificates/intermediate_ca.crt
sudo /usr/sbin/update-ca-certificates

[[ -f /usr/bin/python ]] || sudo ln -s /usr/bin/python3 /usr/bin/python
