# code-server

```bash
kubectl create ns code-server
kubectl label namespace code-server istio-injection=enabled
kubectl apply -f ./kube/code-server.yaml -n code-server
kubectl get all -n code-server

kubectl apply -f - <<EOF

EOF

kubectl apply -f - -n code-server <<EOF

EOF

kubectl edit gateway 



kubectl api-resources --verbs=list --namespaced -o name   | xargs -n 1 kubectl get --show-kind --ignore-not-found -n istio-system
```
