#!/bin/bash

set -e

# ---------------------------
# Configurable Variables
# ---------------------------
CLUSTER_NAME="argocd-cluster"
KIND_CONFIG="kind-config.yaml"
NAMESPACE="argocd"

# ---------------------------
# Detect host IP automatically
# ---------------------------
HOST_IP=$(hostname -I | awk '{print $1}')
echo "Detected host IP: $HOST_IP"

# ---------------------------
# Create Kind Cluster Config
# ---------------------------
cat > $KIND_CONFIG <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: "$HOST_IP"
  apiServerPort: 33893
nodes:
  - role: control-plane
    image: kindest/node:v1.33.1
  - role: worker
    image: kindest/node:v1.33.1
  - role: worker
    image: kindest/node:v1.33.1
EOF

# ---------------------------
# Create Kind Cluster
# ---------------------------
echo "📦 Creating Kind cluster: $CLUSTER_NAME ..."
if kind get clusters | grep -q $CLUSTER_NAME; then
  echo "⚠️ Cluster $CLUSTER_NAME already exists. Skipping creation."
else
  kind create cluster --name $CLUSTER_NAME --config $KIND_CONFIG
fi

echo "✅ Kind cluster is ready."
kubectl cluster-info
kubectl get nodes

# ---------------------------
# Create ArgoCD Namespace
# ---------------------------
kubectl create namespace $NAMESPACE || echo "⚠️ Namespace $NAMESPACE already exists."

# ---------------------------
# Install ArgoCD using Helm only
# ---------------------------
echo "🚀 Installing ArgoCD using Helm..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install argocd argo/argo-cd -n $NAMESPACE

# ---------------------------
# Install ArgoCD CLI (Ubuntu only)
# ---------------------------
echo "⏳ Checking if ArgoCD CLI is installed..."
if ! command -v argocd &> /dev/null
then
    echo "🚀 Installing ArgoCD CLI (Ubuntu)..."

    ARCH=$(uname -m)
    if [ "$ARCH" == "x86_64" ]; then
        BINARY="argocd-linux-amd64"
    elif [ "$ARCH" == "aarch64" ]; then
        BINARY="argocd-linux-arm64"
    else
        echo "❌ Unsupported architecture: $ARCH"
        exit 1
    fi

    curl -sSL -o $BINARY https://github.com/argoproj/argo-cd/releases/latest/download/$BINARY
    sudo install -m 555 $BINARY /usr/local/bin/argocd
    rm $BINARY

    echo "✅ ArgoCD CLI installed successfully."
else
    echo "✅ ArgoCD CLI already installed."
fi

# ---------------------------
# Verify Installation
# ---------------------------
echo "⏳ Waiting for ArgoCD server deployment..."
kubectl wait --for=condition=Available deployment/argocd-server -n $NAMESPACE --timeout=300s || true

kubectl get pods -n $NAMESPACE
kubectl get svc -n $NAMESPACE

# ---------------------------
# Access Instructions
# ---------------------------
echo "🔑 Fetching ArgoCD initial admin password..."
PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n $NAMESPACE -o jsonpath="{.data.password}" | base64 -d)
echo "$PASSWORD"

echo ""
echo "🌐 To access the ArgoCD UI, run:"
echo "kubectl port-forward svc/argocd-server -n $NAMESPACE 8080:443 --address=0.0.0.0 &"
echo "Then open: https://$HOST_IP:8080"
echo "Login with username: admin and the password above."
echo "-----------------------------------------"
echo "🔐 CLI Login Example:"
echo "argocd login $HOST_IP:8080 --username admin --password $PASSWORD --insecure"
echo "argocd account get-user-info" 
echo "========================================="
