# Traefik

https://doc.traefik.io/traefik/getting-started/install-traefik/#use-the-helm-chart

helm repo add traefik https://helm.traefik.io/traefik
helm repo update
kubectl create ns traefik
kubectl apply -f ./traefik-config.yaml
helm install --values=./custom-values.yaml --namespace=traefik traefik traefik/traefik
kubectl apply -f dashboard.yaml

kubectl apply -f whoami.yaml
helm upgrade --values=./custom-values.yaml --namespace=traefik traefik traefik/traefik
