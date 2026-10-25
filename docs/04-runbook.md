# Operations Runbook — bring the IDP platform up (and down)

## The one mental model
Terraform builds the **AWS boxes** (VPC, EKS cluster, worker nodes). It does **NOT** manage
anything *inside* the cluster. So `terraform destroy` wipes ArgoCD, the repo connection, the
apps, and the monitoring stack — but your laptop tools (kubectl/helm/aws-vault) and your Git
repo survive. This runbook rebuilds that "inside-the-cluster" world **from Git**.

```
Terraform  →  AWS boxes (VPC, EKS, nodes)         ← destroyed nightly to save money
ArgoCD     →  everything inside the cluster        ← restored from Git by this runbook
```

## Ground rules (read once)
- **Run everything inside aws-vault.** kubectl / helm / aws all need live AWS credentials.
  Wrap commands like: `aws-vault exec terraform --no-session -- <command>`
  or open one shell: `aws-vault exec terraform --no-session` and run freely inside it.
- Region: `us-east-1`  ·  Cluster: `idp-dev-cluster`  ·  Account: `600406561872`
- Repo: `https://github.com/wesley-codes/idp-infra.git`  ·  GitHub user: `wesley-codes`
- Linux/EKS is **case-sensitive**: the folder is `gitops` (lowercase). Type it exactly.

---

## STEP 1 — Bring up the AWS cluster (Terraform)
```bash
cd environments/dev
aws-vault exec terraform --no-session -- terraform apply    # ~10–15 min for EKS + nodes
```
(If the account-wide pieces were destroyed too, apply `environments/global` first.)

## STEP 2 — Point kubectl at the cluster
```bash
aws-vault exec terraform --no-session -- aws eks update-kubeconfig \
  --name idp-dev-cluster --region us-east-1

aws-vault exec terraform --no-session -- kubectl get nodes   # nodes should be Ready
```

## STEP 3 — Install ArgoCD + open the UI
```bash
aws-vault exec terraform --no-session -- ./scripts/argocd-up.sh
```
This installs/upgrades ArgoCD via Helm, prints the admin login (user `admin`), and opens the
UI tunnel on https://localhost:8080 (leave it running; Ctrl-C stops it).

Quick check ArgoCD is up (in another aws-vault shell):
```bash
kubectl get pods -n argocd     # all pods Running
```

## STEP 4 — Connect the private repo (read-only token)
ArgoCD needs read access to the private repo. The token is a SECRET — it lives in your shell,
never in Git. Use a GitHub fine-grained token (Contents: Read-only, this repo only).
```bash
export GITHUB_TOKEN=github_pat_xxx        # your read-only token

kubectl -n argocd create secret generic idp-infra-repo \
  --from-literal=type=git \
  --from-literal=url=https://github.com/wesley-codes/idp-infra.git \
  --from-literal=username=wesley-codes \
  --from-literal=password="$GITHUB_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n argocd label secret idp-infra-repo \
  argocd.argoproj.io/secret-type=repository --overwrite
```
(Or connect it in the ArgoCD UI → Settings → Repositories. `scripts/bootstrap-cluster.sh`
automates this step.)

## STEP 5 — Apply the root app (app-of-apps) — the ONLY manual apply
```bash
kubectl apply -f gitops/bootstrap/root-app.yaml
```
`root` reads `gitops/apps/` and creates every app it finds there (web, monitoring, …). You
never apply those individually again — drop a new file in `gitops/apps/`, push, and root
creates it on its own.

## STEP 6 — Verify everything is healthy
```bash
kubectl get applications -n argocd
# expect: root, web, kube-prometheus-stack  →  all Synced / Healthy
#         (monitoring can sit in Progressing for a few minutes — it's a big chart)

kubectl get pods -n default        # web pod: 1/1 Running
kubectl get pods -n monitoring     # prometheus / grafana / operator / node-exporter Running
```

## STEP 7 — Reach the apps (each opens a private tunnel; leave running)
```bash
# Your web app
kubectl port-forward svc/web -n default 8081:80
#   → http://localhost:8081

# Grafana (metrics dashboards)   login: admin / admin
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80
#   → http://localhost:3000
#   (if the service name differs: kubectl get svc -n monitoring | grep grafana)

# ArgoCD UI (already opened by argocd-up.sh)
#   → https://localhost:8080
```

---

## EVERYDAY — ship a code change (the CI/CD loop)
Change something under `app/`, then:
```bash
git pull --rebase        # get the CI bot's auto-commits first (avoids divergent branches)
git add app/
git commit -m "..."
git push
```
The pipeline runs automatically: **Semgrep → build → Trivy scan → push to ECR → write the new
image tag into gitops/web/kustomization.yaml (commit back)**. ArgoCD then pulls the new tag and
deploys it. You never touch the cluster.

## TEARDOWN — stop the meter when done for the day
```bash
cd environments/dev
aws-vault exec terraform --no-session -- terraform destroy
```
Only the AWS boxes go away. Your Git repo is the source of truth — rerun this runbook from
STEP 1 to get everything back.

---

## Troubleshooting cheat-sheet
| Symptom | Cause | Fix |
|---|---|---|
| `UnrecognizedClientException` / `security token is invalid` | Ran a command outside aws-vault (no live creds) | Wrap it: `aws-vault exec terraform --no-session -- <cmd>` |
| `ImagePullBackOff` + ECR list is empty | No image pushed for that tag (repo recreated with `force_delete`) | Push a change under `app/` to rebuild; pipeline repopulates ECR + updates the tag |
| `sed: can't read gitops/...` in CI | Folder casing mismatch (`gitOPs` vs `gitops`) | Check `git ls-tree -r origin/main | grep -i gitops`; rename to lowercase |
| ArgoCD app `Namespace ... is missing` | Manifests have no namespace | Add `namespace: <ns>` to the kustomization.yaml |
| `divergent branches` on `git pull` | CI bot committed while you had local commits | `git pull --rebase` (set default: `git config pull.rebase true`) |
| Pods `Pending` (Insufficient memory) in monitoring | Nodes too small for the stack | Bump node group size or trim the Helm values |
| Lens asks for "SSO Start URL / username" | You use aws-vault (IAM user), not AWS SSO | Skip SSO; launch Lens via aws-vault so its kubeconfig context has creds — or just use Grafana |
