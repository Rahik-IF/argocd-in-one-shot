#!/bin/bash

set -e

# ---------------------------
# Configurable Variables
# ---------------------------
CLUSTER_NAME="argocd-cluster"
KIND_CONFIG="kind-config.yaml"
NAMESPACE="argocd"

echo "========================================="
echo "   🗑️  ArgoCD Cleanup Script"
echo "========================================="
echo "This script will remove:"
echo "  - ArgoCD installation from namespace: $NAMESPACE"
echo "  - Kind cluster: $CLUSTER_NAME"
echo "  - Kind config file: $KIND_CONFIG"
echo "  - ArgoCD CLI (optional)"
echo "-----------------------------------------"
read -p "⚠️  Are you sure you want to proceed? [y/N]: " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "❌ Cleanup cancelled."
    exit 0
fi

# ---------------------------
# Check if cluster exists
# ---------------------------
echo "🔍 Checking if Kind cluster exists..."
if ! kind get clusters | grep -q $CLUSTER_NAME; then
  echo "⚠️  Cluster $CLUSTER_NAME does not exist. Nothing to clean up."
else
  # ---------------------------
  # Uninstall ArgoCD
  # ---------------------------
  echo "🗑️  Uninstalling ArgoCD from namespace: $NAMESPACE..."
  if kubectl get namespace $NAMESPACE &> /dev/null; then
    echo "🚀 Deleting ArgoCD manifests..."
    kubectl delete -n $NAMESPACE \
      -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml \
      --ignore-not-found=true || echo "⚠️  Some resources may have already been deleted."
    
    echo "🗑️  Deleting namespace: $NAMESPACE..."
    kubectl delete namespace $NAMESPACE --ignore-not-found=true
    echo "✅ ArgoCD uninstalled successfully."
  else
    echo "⚠️  Namespace $NAMESPACE does not exist."
  fi

  # ---------------------------
  # Delete Kind Cluster
  # ---------------------------
  echo "🗑️  Deleting Kind cluster: $CLUSTER_NAME..."
  kind delete cluster --name $CLUSTER_NAME
  echo "✅ Kind cluster deleted successfully."
fi

# ---------------------------
# Remove Kind Config File
# ---------------------------
if [ -f "$KIND_CONFIG" ]; then
  echo "🗑️  Removing Kind config file: $KIND_CONFIG..."
  rm -f $KIND_CONFIG
  echo "✅ Config file removed."
else
  echo "⚠️  Config file $KIND_CONFIG not found."
fi

# ---------------------------
# Optional: Uninstall ArgoCD CLI
# ---------------------------
echo "-----------------------------------------"
read -p "❓ Do you want to uninstall ArgoCD CLI as well? [y/N]: " remove_cli

if [[ "$remove_cli" =~ ^[Yy]$ ]]; then
  if command -v argocd &> /dev/null; then
    echo "🗑️  Uninstalling ArgoCD CLI..."
    sudo rm -f /usr/local/bin/argocd
    echo "✅ ArgoCD CLI uninstalled successfully."
  else
    echo "⚠️  ArgoCD CLI is not installed."
  fi
else
  echo "ℹ️  ArgoCD CLI kept intact."
fi

echo ""
echo "========================================="
echo "✅ Cleanup completed successfully!"
echo "========================================="
echo "All ArgoCD resources have been removed."
echo "Your system is now in its previous state."
echo "========================================="