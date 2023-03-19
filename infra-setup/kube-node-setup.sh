#!/bin/bash

if [ -z ${K8sVersion+x} ]; then K8sVersion="1.25.8-00"; fi
if [ -z ${PodCIDR+x} ]; then PodCIDR="172.16.0.0/16"; fi
if [ -z ${ServiceCDR+x} ]; then ServiceCDR="172.17.0.0/16"; fi
if [ -z ${IngressRange+x} ]; then IngressRange="192.168.0.130-192.168.0.140"; fi
if [ -z ${MasterIP+x} ]; then MasterIP="192.168.0.128"; fi
if [ -z ${MasterName+x} ]; then MasterName="arc-kube-master"; fi
if [ -z ${NFSCIDR+x} ]; then NFSCIDR="192.168.0.128/25"; fi

#General update
sudo sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'a'"'"';/g' /etc/needrestart/needrestart.conf
sudo apt update
sudo apt upgrade -y

#Install base tools
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    gnupg2 \
    lsb-release \
    mc \
    curl \
    software-properties-common \
    net-tools \
    nfs-common \
    dstat \
    git \
    curl \
    htop \
    nano \
    bash-completion \
    vim \
    jq


#Disable Swap
sudo sed -i '/swap/ s/^\(.*\)$/#\1/g' /etc/fstab
sudo swapoff -a

#Configure hosts file and routes
echo "$MasterIP $MasterName" | sudo tee -a /etc/hosts

#Enable kernel modules and setup sysctl
sudo modprobe overlay
sudo modprobe br_netfilter

echo overlay | sudo tee -a /etc/modules
echo br_netfilter | sudo tee -a /etc/modules

sudo tee /etc/sysctl.d/kubernetekubs.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
fs.inotify.max_user_instances=524288
EOF

sudo sysctl --system

#Install containerd
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y containerd.io

# Configure containerd
sudo bash -c "containerd config default > /etc/containerd/config.toml"
sudo sed -i "s+SystemdCgroup = false+SystemdCgroup = true+g" /etc/containerd/config.toml

sudo systemctl daemon-reload 
sudo systemctl restart containerd
sudo systemctl enable containerd


#Install kubelet, kubeadm, kubectl
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
sudo apt -y install kubelet=$K8sVersion kubeadm=$K8sVersion kubectl=$K8sVersion
sudo apt-mark hold kubelet kubeadm kubectl

echo 'source <(kubectl completion bash)' >> /home/*/.bashrc
echo 'source <(kubectl completion zsh)' >> /home/*/.zshrc

#Install Helm
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm

#Configure master node
sudo systemctl enable kubelet
sudo kubeadm config images pull

cat << EOF > kubeadm.conf
kind: ClusterConfiguration
apiVersion: kubeadm.k8s.io/v1beta3
kubernetesVersion: $(echo $K8sVersion | cut -f1 -d "-")
networking:
  dnsDomain: cluster.local
  serviceSubnet: $ServiceCDR
  podSubnet: $PodCIDR
controlPlaneEndpoint: $MasterName
---
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: systemd
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "ipvs"
ipvs:
  strictARP: true
EOF


sudo kubeadm init --config kubeadm.conf

for u in $(ls /home); do
  rm -Rf /home/${u}/.kube
  mkdir -p /home/${u}/.kube
  sudo cp -f /etc/kubernetes/admin.conf /home/${u}/.kube/config
  sudo chown -R ${u}:${u} /home/${u}/.kube
done

rm -Rf $HOME/.kube
mkdir -p $HOME/.kube
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config

# Configure crictl
sudo tee /etc/crictl.yaml<<EOF
runtime-endpoint: unix:///var/run/containerd/containerd.sock
image-endpoint: unix:///var/run/containerd/containerd.sock
timeout: 10
debug: false
EOF

#Waiting for the K8s API server to come up
test=$(kubectl get pods -A 2>&1)
while ( echo $test | grep -q "refuse\|error" ); do echo "API server is still down..."; sleep 5; test=$(kubectl get pods -A 2>&1); done

kubectl taint nodes --all node-role.kubernetes.io/master-
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

#Configre Calico as network plugin
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/tigera-operator.yaml

curl https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/custom-resources.yaml -s -o /tmp/custom-resources.yaml
sed -i "s+192.168.0.0/16+$PodCIDR+g" /tmp/custom-resources.yaml
sed -i "s+blockSize: 26+blockSize: 24+g" /tmp/custom-resources.yaml
kubectl create -f /tmp/custom-resources.yaml
rm /tmp/custom-resources.yaml


#Configure MetalLB
#kubectl get configmap kube-proxy -n kube-system -o yaml | \
#sed -e "s/strictARP: false/strictARP: true/" | \
#kubectl apply -f - -n kube-system

#kubectl get configmap kube-proxy -n kube-system -o yaml | \
#sed -e 's/mode: ""/mode: "IPVS"/' | \
#kubectl apply -f - -n kube-system

helm repo add metallb https://metallb.github.io/metallb

kubectl create ns metallb-system
kubectl label namespace metallb-system pod-security.kubernetes.io/enforce=privileged
kubectl label namespace metallb-system pod-security.kubernetes.io/audit=privileged
kubectl label namespace metallb-system pod-security.kubernetes.io/warn=privileged
kubectl label namespace metallb-system app=metallb
helm install metallb metallb/metallb -n metallb-system --wait \
  --set crds.validationFailurePolicy=Ignore

# TODO: add a checker here which waits for metallb to come up. Otherwise the next commands will fail.
# The below sleep is added as a workaround meanwhile.

#Waiting for the K8s API server to come up
#test=$(kubectl get deployments.apps -n metallb-system -o json metallb-controller |jq .status.conditions[0].type -r 2>&1)
#while ( ! (echo $test | grep -q "Available") ); do
#  echo "MetalLB is not ready";
#  sleep 5;
#  test=$(kubectl get deployments.apps -n metallb-system -o json metallb-controller |jq .status.conditions[0].type -r 2>&1);
#done

cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: local-pool
  namespace: metallb-system
spec:
  addresses:
  - $IngressRange
EOF

cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: advertizer
  namespace: metallb-system
EOF

# Setup NFS share if needed
sudo apt install -y nfs-kernel-server
sudo mkdir -p /mnt/k8s-pv-data
sudo chown -R nobody:nogroup /mnt/k8s-pv-data/
sudo chmod 777 /mnt/k8s-pv-data/

sudo tee -a /etc/exports<<EOF
/mnt/k8s-pv-data  ${NFSCIDR}(rw,sync,no_subtree_check)
EOF

sudo exportfs -a
sudo systemctl restart nfs-kernel-server

# Install NFS-provisioner
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    -n kube-system \
    --set nfs.server=$MasterIP \
    --set nfs.path=/mnt/k8s-pv-data \
    --set storageClass.name=default \
    --set storageClass.defaultClass=true

# Install Metrics Server
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm upgrade --install metrics-server metrics-server/metrics-server \
    --set args={--kubelet-insecure-tls} \
    --set hostNetwork.enabled=true \
    -n kube-system

## Install NVIDIA device plugin
#sudo apt install -y nvidia-driver-510 nvidia-cuda-toolkit

#kubectl create -f https://github.com/kubernetes/kubernetes/raw/master/cluster/addons/device-plugins/nvidia-gpu/daemonset.yaml
#kubectl label nodes kubemaster cloud.google.com/gke-accelerator=gpu

echo "Install and setup ready. Restart in 10 seconds."
echo "After restart it will take some time to reach ready state."
sleep 10

sudo reboot
