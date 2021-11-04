# Kubernetes

## Table of Contents
<!--ts-->
<!--te-->

Image

Container

Pod

Deployment

Service

ReplicaSet

DaemonSet

ConfigMap

PersistentVolume

PersistentVolumeClaim

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


