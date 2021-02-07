# Istio

## Table of Contents
<!--ts-->
<!--te-->

VirtualService - defines the rules that control how requests for a service are routed within an Istio service mesh

DestinationRule - configures the set of policies to be applied to a request after VirtualService has occurred

ServiceEntry - enables requests to services outside an Istio service mesh

Gateway - ingress & egress

[Secure Gateways (SDS)](https://istio.io/v1.4/docs/tasks/traffic-management/ingress/secure-ingress-sds/)

Sidecar 

## [Apply Kubernetes network policies](https://istio.io/latest/docs/tasks/traffic-management/egress/egress-gateway/#apply-kubernetes-network-policies)

```bash
kubectl label namespace istio-system istio=system
kubectl label ns kube-system kube-system=true
cat <<EOF | kubectl apply -n test-egress -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-egress-to-istio-system-and-kube-dns
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kube-system: "true"
    ports:
    - protocol: UDP
      port: 53
  - to:
    - namespaceSelector:
        matchLabels:
          istio: system
EOF
```

## [Egress Gateway](https://istio.io/latest/docs/tasks/traffic-management/egress/egress-gateway)


To see if you have any egress gateways defined.
```bash
kubectl get pod -l istio=egressgateway -n istio-system
```

Create a ServiceEntry
```bash
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: edition-cnn-com
spec:
  hosts:
  - edition.cnn.com
  ports:
  - number: 80
    name: http-port
    protocol: HTTP
    targetPort: 443
  - number: 443
    name: https-port
    protocol: HTTPS
  resolution: DNS
EOF
```

Create gateway
```bash
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: istio-egressgateway
spec:
  selector:
    istio: egressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - edition.cnn.com
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: egressgateway-for-cnn
spec:
  host: istio-egressgateway.istio-system.svc.cluster.local
  subsets:
  - name: cnn
EOF
```

Define a VirtualService to direct traffic from the sidecars to the egress gateway and from the egress gateway to the external service
```bash
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: direct-cnn-through-egress-gateway
spec:
  hosts:
  - edition.cnn.com
  gateways:
  - istio-egressgateway
  - mesh
  http:
  - match:
    - gateways:
      - mesh
      port: 80
    route:
    - destination:
        host: istio-egressgateway.istio-system.svc.cluster.local
        subset: cnn
        port:
          number: 80
      weight: 100
  - match:
    - gateways:
      - istio-egressgateway
      port: 80
    route:
    - destination:
        host: edition.cnn.com
        port:
          number: 80
      weight: 100
EOF
```

## Toubleshooting 

```bash
kubectl exec -i -n istio-system "$(kubectl get pod -l istio=egressgateway -n istio-system -o jsonpath='{.items[0].metadata.name}')"  -- cat /etc/certs/cert-chain.pem | openssl x509 -text -noout  | grep 'Subject Alternative Name' -A 1
```

## [Egress TLS Origination](https://istio.io/latest/docs/tasks/traffic-management/egress/egress-tls-origination/)


## [Egress Gateways with TLS Origination (SDS)](https://istio.io/latest/docs/tasks/traffic-management/egress/egress-gateway-tls-origination-sds/)

Create a Kubernetes Secret to hold the CA certificate used by egress gateway to originate TLS connections:
```bash
kubectl create secret generic client-credential-cacert --from-file=ca.crt=example.com.crt -n istio-system
```
Note that the secret name for an Istio CA-only certificate must end with -cacert and the secret must be created in the same namespace as Istio is deployed in, istio-system in this case.