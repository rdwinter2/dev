#!/bin/bash

curl -fsS https://raw.githubusercontent.com/grafana/loki/master/tools/promtail.sh | sh -s uuu xxxx logs-prod-us-central1.grafana.net default | kubectl apply --namespace=default -f  -
