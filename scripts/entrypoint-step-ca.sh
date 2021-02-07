#!/usr/bin/env bash

export DEFAULT_CERT_VALIDITY=${DEFAULT_CERT_VALIDITY-"720h"}
export MAX_CERT_VALIDITY=${MAX_CERT_VALIDITY-"2160h"}

PASSWORDPATH=/home/step/secrets/password
CONFIGPATH=/home/step/config/ca.json
DNSNAMES=$1
CA_SERVER=$2
RESOLVER=$3
SUBORDINATE_CERT=$4
SUBORDINATE_KEY=$5
SUB_SIGNED_BY_CERT=$6

echo "$DNSNAMES $CA_SERVER $SUBORDINATE_CERT $SUBORDINATE_KEY $SUB_SIGNED_BY_CERT"

[[ -d /home/step/secrets ]] || mkdir -p /home/step/secrets
[[ -f $PASSWORDPATH ]] || echo $(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1) > $PASSWORDPATH

[[ -f $CONFIGPATH ]] || FIRST_TIME=1
if [[ -n "$FIRST_TIME" ]]; then
  echo "This is the first time Step CA has started"
fi
# initialize step-ca as a self-signed root ca
[ -n "$FIRST_TIME" ] && $(step ca init --name=step --provisioner=admin --dns=$DNSNAMES --with-ca-url=$CA_SERVER --address=:8443 --password-file=$PASSWORDPATH)

# if $SUBORDINATE_CERT is unset or the empty string create a selfsigned root
if [[ -n "$FIRST_TIME" && -n "${SUBORDINATE_CERT}" ]]; then
  echo "Converting to function as a subordinate CA"
  echo "Removing root CA key"
  rm -f $(step path)/secrets/root_ca_key
  echo "Copying ${SUBORDINATE_KEY} to intermediate_ca_key"
  cp /secrets/${SUBORDINATE_KEY} $(step path)/secrets/intermediate_ca_key
  echo "Copying the password file of ${SUBORDINATE_KEY}"
  cp /secrets/password $(step path)/secrets/password
  chmod 600 $(step path)/secrets/*
  echo "Copying ${SUBORDINATE_CERT} to intermediate_ca.crt"
  cp /certs/${SUBORDINATE_CERT} $(step path)/certs/intermediate_ca.crt
  echo "Copying ${SUB_SIGNED_BY_CERT} to root_ca.crt"
  cp /certs/${SUB_SIGNED_BY_CERT} $(step path)/certs/root_ca.crt
  chmod 600 $(step path)/certs/*
  echo "Fixing the fingerprint"
  sed -i "s@\"fingerprint\": .*@\"fingerprint\": \"$(step certificate fingerprint $(step path)/certs/root_ca.crt)\",@" $(step path)/config/defaults.json

  echo "Editing $CONFIGPATH to fix low ram issue"
  # Set certificate validity period
  #echo $(cat config/ca.json | /usr/bin/jq --arg DEFAULT_CERT_VALIDITY "$DEFAULT_CERT_VALIDITY" --arg MAX_CERT_VALIDITY "$MAX_CERT_VALIDITY" -r '
  #                              .authority.provisioners[[.authority.provisioners[] 
  #                              | .name=="acme"] 
  #                              | index(true)].claims 
  #                              |= (. + {"maxTLSCertDuration":$MAX_CERT_VALIDITY,"defaultTLSCertDuration":$DEFAULT_CERT_VALIDITY})') > config/ca.json
  sed -i 's/"type": "badger"/"type": "badgerV2","badgerFileLoadingMode": "FileIO"/' config/ca.json
  #        "db": {
  #              "type": "badgerV2",
  #              "dataSource": "/home/step/db",
  #              "badgerFileLoadingMode": "FileIO"
  #      },

fi

if grep -q '"type": "ACME"' $CONFIGPATH; then
  : # already configured ACME
else
  step ca provisioner add acme --type ACME
fi

echo "step ca provisioner add admin /home/step/certs/intermediate_ca.crt --type=JWK --password-file=/home/step/secrets/password "
echo "step ca bootstrap --ca-url=${CA_SERVER} --fingerprint=$(step certificate fingerprint /home/step/certs/root_ca.crt) --install"
echo "step ca root root_ca.crt --ca-url ${CA_SERVER} --fingerprint $(step certificate fingerprint /home/step/certs/root_ca.crt)"
echo "step ca health --ca-url https://localhost:8443 --root $(step path)certs/root_ca.crt"

#/usr/local/bin/step-ca --password-file $PASSWORDPATH --resolver $RESOLVER $CONFIGPATH 
cmd="/usr/local/bin/step-ca --password-file $PASSWORDPATH --resolver $RESOLVER $CONFIGPATH"
echo "Starting step-ca with cmd: $cmd"
exec /bin/sh -c "$cmd"
