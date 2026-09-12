#!/usr/bin/env bash

set -euo pipefail

# ----------------------------- config -----------------------------
CLUSTER_NAME="idp-dev-cluster"
REGION="us-east-1"
UI_PORT="8080"
# ------------------------------------------------------------------

echo "==> 1/4  Point kubectl at the cluster"
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"

echo "==> 2/4  Install or upgrade ArgoCD via Helm"
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  --wait --timeout 10m

echo "==> 3/4  Wait for the ArgoCD server to be ready"
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s

echo "==> 4/4  Admin login"
echo "    username: admin"
if kubectl -n argocd get secret argocd-initial-admin-secret >/dev/null 2>&1; then
  PW="$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
  echo "    password: ${PW}"
else
  echo "    password: (initial-admin secret not found — it may have been rotated/removed)"
fi

echo
echo "Opening the UI on https://localhost:${UI_PORT}  (accept the self-signed cert)."
echo "Leave this running; press Ctrl-C to stop the tunnel."
echo
exec kubectl port-forward svc/argocd-server -n argocd "${UI_PORT}:443"
