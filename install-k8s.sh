#!/bin/bash
set -euo pipefail

KUBERNETES_VERSION=v1.32
CRIO_VERSION=v1.32
UBUNTU_CODENAME=xUbuntu_22.04

echo ">>> Cleaning old CRI-O sources"
sudo rm -f /etc/apt/sources.list.d/*cri-o*
sudo rm -f /etc/apt/keyrings/*cri-o*

echo ">>> Disabling swap"
sudo swapoff -a
sudo sed -i.bak '/ swap / s/^/#/' /etc/fstab

echo ">>> Installing dependencies"
sudo apt-get update
sudo apt-get install -y software-properties-common curl gpg apt-transport-https ca-certificates

echo ">>> Adding Kubernetes v$KUBERNETES_VERSION APT repo"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/${KUBERNETES_VERSION}/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${KUBERNETES_VERSION}/deb/ /" | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

echo ">>> Adding CRI-O v$CRIO_VERSION APT repo (✅ New official one)"
curl -fsSL https://download.opensuse.org/repositories/isv:/cri-o:/stable:/${CRIO_VERSION}/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://download.opensuse.org/repositories/isv:/cri-o:/stable:/${CRIO_VERSION}/deb/ /" | \
  sudo tee /etc/apt/sources.list.d/cri-o.list

echo ">>> Loading kernel modules"
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

echo ">>> Applying sysctl settings"
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

echo ">>> Installing Kubernetes & CRI-O"
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl cri-o
sudo apt-mark hold kubelet kubeadm kubectl

echo ">>> Starting CRI-O"
sudo systemctl daemon-reexec
sudo systemctl enable --now crio

echo ">>> Verifying CRI-O runtime"
sudo crictl config --set runtime-endpoint=unix:///var/run/crio/crio.sock
sudo crictl info

echo "✅ Installation complete: Kubernetes v$KUBERNETES_VERSION with CRI-O v$CRIO_VERSION"
