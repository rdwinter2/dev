# Kubernetes on Docker Desktop

```bash
# Install some CLIs
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
sudo apt-get update -yqq
sudo apt-get install -yqq apt-transport-https bash-completion ca-certificates dnsutils gnupg-agent python-jinja2 python-yaml python-crypto software-properties-common wget jq jid build-essential gcc htop unzip zsh
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
sudo apt-get update -yqq
sudo apt-get install -yqq docker-ce docker-ce-cli containerd.io

sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $(whoami)
newgrp docker

ssh-keygen -o -a 100 -t ed25519 -f ~/.ssh/id_ed25519 -N "" -C "$(whoami)@$(hostname)"
t=$(mktemp -d); pushd $t
VERSION=$(curl -fsSL "https://api.github.com/repos/kubernetes-sigs/kind/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/' | cut -c2-)
curl -fsSL -o ./kind https://github.com/kubernetes-sigs/kind/releases/download/v${VERSION}/kind-linux-amd64
sudo install --mode=755 --owner=root ./kind /usr/local/bin
curl -fsSL -O "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install --mode=755 --owner=root ./kubectl /usr/local/bin
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
VERSION=$(curl -fsSL "https://api.github.com/repos/derailed/k9s/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/' | cut -c2-)
curl -fsSL https://github.com/derailed/k9s/releases/download/v${VERSION}/k9s_Linux_x86_64.tar.gz | tar xzf - 
sudo install --mode=755 --owner=root ./k9s /usr/local/bin
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
sudo mv kustomize /usr/local/bin/kustomize
popd
pushd /opt
VERSION=$(curl -fsSL "https://api.github.com/repos/istio/istio/releases" | jq '.[].tag_name' | sed 's/"//g' | grep -v "\-alpha\|\-beta\|\-rc" | sort --version-sort | tail -1)
curl -fsSL https://github.com/istio/istio/releases/download/${VERSION}/istio-${VERSION}-linux-amd64.tar.gz | sudo tar -xzf -
# Get the Cilium enhanced Istio
VERSION=$(curl -fsSL "https://api.github.com/repos/cilium/istio/releases" | jq '.[].tag_name' | sed 's/"//g' | grep -v "\-alpha\|\-beta\|\-rc" | sort --version-sort | tail -1)
curl -fsSL https://github.com/cilium/istio/releases/download/${VERSION}/cilium-istioctl-${VERSION}-linux-amd64.tar.gz | sudo tar -xzf -
sudo install --mode=755 --owner=root ./cilium-istioctl /opt/istio/bin
sudo ln -s /opt/istio-${VERSION} istio
sudo chmod o+rx /opt/istio /opt/istio/bin /opt/istio/tools
sudo chmod o+r /opt/istio/manifest.yaml
export PATH="$PATH:/opt/istio/bin"
popd

kind create cluster --name kind --image kindest/node:v1.22.1@sha256:100b3558428386d1372591f8d62add85b900538d94db8e455b66ebaf05a3ca3a --config=./kind.yaml

kind export kubeconfig --name kind
kubectl cluster-info --context kind-kind

# Install cilium
helm repo add cilium https://helm.cilium.io/

docker pull cilium/cilium:v1.10.3
kind load docker-image cilium/cilium:v1.10.3

helm install cilium cilium/cilium --version 1.10.3 \
   --namespace kube-system \
   --set nodeinit.enabled=true \
   --set kubeProxyReplacement=partial \
   --set hostServices.enabled=false \
   --set externalIPs.enabled=true \
   --set nodePort.enabled=true \
   --set hostPort.enabled=true \
   --set bpf.masquerade=false \
   --set image.pullPolicy=IfNotPresent \
   --set ipam.mode=kubernetes

k() {
  local retries=0
  local attempts=60
  while true; do
    if kubectl "$@"; then
      break
    fi

    ((retries += 1))
    if [[ "${retries}" -gt ${attempts} ]]; then
      echo "error: 'kubectl $*' did not succeed, failing"
      exit 1
    fi
    echo "info: waiting for 'kubectl $*' to succeed..."
    sleep 1
  done
}
k  scale deployment --replicas 1 cilium-operator --namespace kube-system
docker exec -it  kind-control-plane crictl images
docker exec -it  kind-worker crictl images
docker exec -it  kind-worker2 crictl images
docker exec -it  kind-worker3 crictl images


cat <<-EOT | kind create cluster --config=-
apiVersion: kind.x-k8s.io/v1alpha4
kind: Cluster
networking:

  apiServerAddress: "127.0.0.1"
  apiServerPort: 6443
  podSubnet: "10.240.0.0/16"
  serviceSubnet: "10.0.0.0/16"
  disableDefaultCNI: true
nodes:
- role: control-plane
  image: kindest/node:v1.22.1@sha256:100b3558428386d1372591f8d62add85b900538d94db8e455b66ebaf05a3ca3a
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 30000
    hostPort: 80
    listenAddress: "127.0.0.1"
    protocol: TCP
  - containerPort: 30001
    hostPort: 443
    listenAddress: "127.0.0.1"
    protocol: TCP
  - containerPort: 30002
    hostPort: 15021
    listenAddress: "127.0.0.1"
    protocol: TCP
EOT
# Calico
curl https://docs.projectcalico.org/manifests/calico.yaml | kubectl apply -f -

# CoreDNS
kubectl scale deployment --replicas 1 coredns --namespace kube-system

# Metrics Server
helm repo add stable https://kubernetes-charts.storage.googleapis.com
helm repo update
helm upgrade metrics-server --install --set "args={--kubelet-insecure-tls, --kubelet-preferred-address-types=InternalIP}" stable/metrics-server --namespace kube-system



# Install MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.10.2/manifests/namespace.yaml
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.10.2/manifests/metallb.yaml
export address_prefix=$(docker network inspect kind | jq ".[0].IPAM.Config[0].Gateway" | sed -e 's/"//g' | awk -F. '{print $1 "." $2}')
echo $address_prefix
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - $address_prefix.255.200-$address_prefix.255.250
EOF

# Install the Cilium enhanced Istio



cilium-istioctl install -y -f ./kind-istio.yaml
kubectl label namespace default istio-injection=enabled
cd /opt/istio
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml

for service in productpage-service productpage-v1 details-v1 reviews-v1; do \
  kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/v1.10.3/examples/kubernetes-istibookinfo-${service}.yaml
done



export CILIUM_NAMESPACE=kube-system
helm upgrade cilium cilium/cilium --version 1.10.3 \
   --namespace $CILIUM_NAMESPACE \
   --reuse-values \
   --set hubble.listenAddress=":4244" \
   --set hubble.relay.enabled=true \
   --set hubble.ui.enabled=true


# Test it out
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 2 # tells deployment to run 2 pods matching the template
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.14.2
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx
spec:
  ports:
  - name: http
    port: 8080
    protocol: TCP
    targetPort: 80
  selector:
    app: nginx
  type: LoadBalancer
EOF


# Sonatype Nexus in K8s
# Docker Desktop Persistent Volumes

sudo mkdir -p /data/nexus-data
sudo chmod -R 777 /data/nexus-data
cat <<EOF | kubectl apply -f -
kind: PersistentVolume
apiVersion: v1
metadata:
  name: nexus-data
  labels:
    type: local
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  storageClassName: manual
  hostPath:
    path: "/data/nexus-data"
EOF
kubectl get pv

cat <<EOF | kubectl create -f -
apiVersion: v1
kind: Namespace
metadata:
  name: nexus 
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nexus-pvc
  namespace: nexus
  labels:
    app: nexus
  # For GluserFS only
  # annotations:
  #  volume.beta.kubernetes.io/storage-class: glusterfs-storage
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: manual
  resources:
    requests:
      storage: 10Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nexus
  namespace: nexus
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nexus
  template:
    metadata:
      labels:
        app: nexus
    spec:
      containers:
        - name: nexus
          image: sonatype/nexus3:3.33.1
          imagePullPolicy: Always
          env:
          - name: MAX_HEAP
            value: "800m"
          - name: MIN_HEAP
            value: "300m"
          resources:
            limits:
              memory: "4Gi"
              cpu: "1000m"
            requests:
              memory: "2Gi"
              cpu: "500m"
          ports:
            - containerPort: 8081
          volumeMounts:
            - name: nexus-data
              mountPath: /nexus-data
      volumes:
        - name: nexus-data
          persistentVolumeClaim:
            claimName: nexus-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: nexus
  namespace: nexus
  annotations:
      prometheus.io/scrape: 'true'
      prometheus.io/path:   /
      prometheus.io/port:   '8081'
spec:
  selector:
    app: nexus
  ports:
  - port: 80
    targetPort: 8081
    protocol: TCP
    name: http
  type: LoadBalancer





#  - port: 5000
#    targetPort: 5000
#    protocol: TCP
#    name: docker 
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: nexus-ingress
  namespace: nexus
  annotations:
    ingress.kubernetes.io/proxy-body-size: 100m
    kubernetes.io/tls-acme: "true"
    kubernetes.io/ingress.class: "nginx"
spec:
  tls:
  - hosts:
    # CHANGE ME
    - docker.YOURDOMAIN.com
    - nexus.YOURDOMAIN.com 
    secretName: nexus-tls
  rules:
  # CHANGE ME
  - host: nexus.YOURDOMAIN.com 
    http:
      paths:
      - path: /
        backend:
          serviceName: nexus
          servicePort: 80
  # CHANGE ME
  - host: docker.YOURDOMAIN.com 
    http:
      paths:
      - path: /
        backend:
          serviceName: nexus
          servicePort: 5000
EOF


cat <<EOF | kubectl create -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: nexus
  namespace: nexus
  labels:
    app: nexus
    group: service
spec:
  replicas: 1
  serviceName: nexus
  selector:
    matchLabels:
      app: nexus
  template:
    metadata:
      labels:
        app: nexus
        group: service
    spec:
      containers:
        - name: nexus
          image: 'sonatype/nexus3:3.33.1'
          imagePullPolicy: IfNotPresent
          env:
            - name: INSTALL4J_ADD_VM_PARAMS
              value: "-Xms2048M -Xmx2048M -XX:MaxDirectMemorySize=3G -XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap"
          resources:
            requests:
              cpu: 500m
              # Based on https://support.sonatype.com/hc/en-us/articles/115006448847#mem
              # and https://twitter.com/analytically/status/894592422382063616:
              #   Xms == Xmx
              #   Xmx <= 4G
              #   MaxDirectMemory >= 2G
              #   Xmx + MaxDirectMemory <= RAM * 2/3 (hence the request for 4800Mi)
              #   MaxRAMFraction=1 is not being set as it would allow the heap
              #     to use all the available memory.
              memory: 8096Mi
            limits:
              memory: "12Gi"
              cpu: "8000m"
          ports:
            - containerPort: 8081
            - containerPort: 5000
          volumeMounts:
            - name: nexus-data
              mountPath: /nexus-data
      securityContext:
        runAsUser: 200
        runAsGroup: 2000
        fsGroup: 2000
      volumes:
        - name: nexus-data
          persistentVolumeClaim:
            claimName: nexus-pvc
EOF


kubectl exec nexus-55976bf6fd-cvhxb -n devops-tools cat /nexus-data/admin.password


helm repo add stable https://charts.helm.sh/stable
helm repo add incubator https://charts.helm.sh/incubator
helm repo update
helm search incubator


https://artifacthub.io/packages/helm/stevehipwell/nexus3


helm repo add stevehipwell https://stevehipwell.github.io/helm-charts/

pushd /opt
VERSION=$(curl -fsSL "https://api.github.com/repos/istio/istio/releases" | jq '.[].tag_name' | sed 's/"//g' | grep -v "\-alpha\|\-beta\|\-rc" | sort --version-sort | tail -1)
curl -fsSL https://github.com/istio/istio/releases/download/${VERSION}/istio-${VERSION}-linux-amd64.tar.gz | sudo tar -xzf -
sudo ln -s /opt/istio-${VERSION} istio
sudo chmod o+rx /opt/istio /opt/istio/bin /opt/istio/tools
sudo chmod o+r /opt/istio/manifest.yaml
export PATH="$PATH:/opt/istio/bin"
popd

yes | istioctl install --set profile=demo
kubectl apply -f samples/addons

kubectl apply -n istio-system -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: "default"
spec:
  mtls:
    mode: STRICT
EOF

kubectl label namespace default istio-injection=enabled
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
kubectl exec "$(kubectl get pod -l app=ratings -o jsonpath='{.items[0].metadata.name}')" -c ratings -- curl -sS productpage:9080/productpage | grep -o "<title>.*</title>"
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
istioctl analyze



kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.11/samples/addons/kiali.yaml
istioctl dashboard kiali



# https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/#are-dns-queries-being-received-processed
kubectl apply -f https://k8s.io/examples/admin/dns/dnsutils.yaml
kubectl exec -i -t dnsutils -- nslookup google.com

```