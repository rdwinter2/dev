#!/usr/bin/env bash

############## EXECUTE ON WSL ###################
cat <<-EOF
############## EXECUTE ON VM ####################
newgrp docker
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
cat <<-EOT > secrets/example.web.key
$(cat ~/.certs/example.web.key)
EOT
cat <<-EOT > certs/example.web.crt
$(cat ~/.certs/example.web.crt)
EOT
sudo cp certs/root_ca.crt /usr/local/share/ca-certificates/root_ca.crt
sudo cp certs/intermediate_ca.crt /usr/local/share/ca-certificates/intermediate_ca.crt
sudo /usr/sbin/update-ca-certificates
docker-compose -f docker-compose-git-sync.yml up -d
sleep 10
docker-compose up
############## EXECUTE ON VM ####################
EOF
############## EXECUTE ON WSL ###################
