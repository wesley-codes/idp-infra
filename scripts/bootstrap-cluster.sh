#!/usr/bin/env bash
#
# bootstrap-cluster.sh
# Run this AFTER `terraform apply` has rebuilt the EKS cluster, to restore the
# in-cluster world that Terraform does NOT manage: kubectl access, ArgoCD, the
# private-repo connection, and the root Application.
#
# Run it inside your aws-vault shell, e.g.:
#   export GITHUB_TOKEN=github_pat_xxx        # your read-only GitHub token
#   aws-vault exec terraform --no-session -- ./scripts/bootstrap-cluster.sh
#
# Safe to re-run: every step is idempotent (install-or-upgrade, apply).

set -euo pipefail

# ----------------------------- config -----------------------------
CLUSTER_NAME="idp-dev-cluster"
REGION="us-east-1"
REPO_URL="https://github.com/wesley-codes/idp-infra.git"
GH_USER="wesley-codes"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# ------------------------------------------------------------------

# The GitHub token is a SECRET — it is never written in this file. It must be
# present as an environment variable when you run the script.
: "${GITHUB_TOKEN:?ERROR: set GITHUB_TOKEN to your read-only GitHub token first (export GITHUB_TOKEN=...)}"

echo "==> 1/5  Point kubectl at the (new) cluster"
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"

echo "==> 2/5  Install or upgrade ArgoCD via Helm"
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  --wait --timeout 10m

echo "==> 3/5  Wait for the ArgoCD server to be ready"
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s

echo "==> 4/5  Connect the private repo (read-only token)"
# Build the repository secret and apply it. The special label is what makes
# ArgoCD treat this secret as a repo credential.
kubectl -n argocd create secret generic idp-infra-repo \
  --from-literal=type=git \
  --from-literal=url="$REPO_URL" \
  --from-literal=username="$GH_USER" \
  --from-literal=password="$GITHUB_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n argocd label secret idp-infra-repo \
  argocd.argoproj.io/secret-type=repository --overwrite

echo "==> 5/5  Create the web Application (ArgoCD then syncs it from Git)"
kubectl apply -f "$SCRIPT_DIR/web-app.yaml"

echo
echo "Done. ArgoCD is restoring your apps from Git."
echo
echo "Open the UI:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "Admin password:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
