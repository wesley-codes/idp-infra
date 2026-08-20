# Phase 3 — GitOps with ArgoCD + Kustomize 

## The one idea
**ArgoCD is a diligent assistant that constantly reads a to-do list and makes the cluster
match it.** The to-do list is your Git repo. You never `kubectl apply` by hand — you
`git push`, and ArgoCD (which is always watching Git) pulls the change and updates the
cluster. If reality ever drifts from Git (someone deletes a pod), ArgoCD puts it back.
That's "self-healing".

```
   you ──git push──▶  Git repo (desired state)
                          │  ArgoCD watches & pulls
                          ▼
                       ArgoCD ──syncs──▶ cluster (actual state)
              drift is auto-corrected back to match Git
```

CI vs CD (how GitHub Actions will fit in Phase 4):
- **GitHub Actions = build & check** (test, scan, build image) — the "kitchen".
- **ArgoCD = deliver** (deploy what's in Git) — the "waiter".
- Actions never touches the cluster; it only writes to Git. ArgoCD is the only thing with
  cluster access, and it just pulls. More secure.

## The moving parts we set up
| Piece | What it is | How it got there |
|---|---|---|
| **ArgoCD** | the GitOps controller (watches Git, syncs cluster) | installed with Helm into the `argocd` namespace |
| **Repo connection** | a read-only key so ArgoCD can read the PRIVATE repo | fine-grained GitHub token (Contents: Read-only, one repo), added in ArgoCD → Settings → Repositories |
| **Application** | the link: "deploy `gitops/web` from this repo into the cluster" | created in the ArgoCD UI (auto-sync + self-heal on) |
| **App manifests** | the actual app (a Deployment + a Service) | `gitops/web/` in this repo |
| **Kustomization** | a "table of contents" + one place for cross-cutting tweaks | `gitops/web/kustomization.yaml` |

## Helm and Kustomize, briefly
- **Helm** = the package manager for Kubernetes. A Helm *chart* is a packaged bundle of
  manifests (like a brew/apt package). We used it to install ArgoCD.
- **Kustomize** = layer changes onto plain YAML without templating. A `kustomization.yaml`
  lists the resources and can stamp cross-cutting changes (labels, name prefixes, replica
  counts) onto all of them at once. ArgoCD auto-detects a `kustomization.yaml` and renders
  through Kustomize automatically.

## App layout
```
gitops/web/
├── deployment.yaml       # run 1 nginx pod
├── service.yaml          # stable front door to the pod
└── kustomization.yaml    # table of contents + shared labels (part-of, team)
```
The label `app: web` is the glue: the Deployment stamps it on its pods, and the Service's
selector uses it to find them.

## Accessing the ArgoCD UI
```bash
# password (username is admin):
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
# open a private tunnel (leave running), then browse to https://localhost:8080
kubectl port-forward service/argocd-server -n argocd 8080:443
```
port-forward is the safe way to reach ArgoCD without exposing it to the internet.

## Restoring after `terraform destroy`
Terraform manages only the AWS boxes (VPC, EKS, nodes) — NOT what's installed inside the
cluster. So a destroy wipes ArgoCD, the repo connection, and the deployed apps. Your laptop
tools (helm, kubectl) and your Git repo survive. After `terraform apply` rebuilds the cluster:
1. `aws eks update-kubeconfig --name idp-dev-cluster --region us-east-1`
2. Re-install ArgoCD with Helm (`helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace`)
3. Reconnect the private repo in the ArgoCD UI (Settings → Repositories)
4. Recreate the `web` Application in the UI (path `gitops/web`)
5. ArgoCD then redeploys everything from Git on its own.
(There's a `scripts/bootstrap-cluster.sh` that automates steps 1–4 if ever wanted.)

## Key commands
```bash
kubectl get pods -n argocd          # ArgoCD's own pods
kubectl get pods -n default         # the web app
kubectl kustomize gitops/web        # preview what Kustomize builds (renders, applies nothing)
```

