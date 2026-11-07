# Operations Runbook: bring the IDP platform up (and down)

## The one mental model
Terraform builds the AWS boxes **and** gives the cluster its "caretaker". ArgoCD then rebuilds
everything else inside the cluster from Git. So one `terraform apply` brings the whole
platform back, and one `terraform destroy` takes it all away.

```
Terraform  →  VPC, EKS cluster, worker nodes      
           →  ArgoCD + repo connection + root app  ← installed by the same apply
ArgoCD     →  web, monitoring, Loki, Alloy         ← restored from gitops/apps/ by root
```

## Ground rules (read once)
- **One owner per thing.** Terraform owns ArgoCD, its repo connection and the root app.
  Never change them with `helm` or `kubectl` by hand: change the Terraform files and run
  `terraform apply`. ArgoCD owns everything in `gitops/`: change those through Git.
- **Run everything inside aws-vault.** terraform / kubectl / aws all need live AWS credentials.
  Open one shell with `aws-vault exec terraform --no-session -- $SHELL` and work inside it.
  `--no-session` is required: without it Terraform can't manage IAM roles.
- **Only run Terraform inside `environments/dev` or `environments/global`.** Those folders have
  a `backend.tf` that keeps state in S3. Anywhere else, Terraform creates a stray, empty
  local `terraform.tfstate`.
- **The GitHub token never goes in a file.** It lives in the macOS Keychain and loads
  automatically into every terminal (see One-time setup).
- Region: `us-east-1` · Cluster: `idp-dev-cluster` · Account: `600406561872`
- Repo: `https://github.com/wesley-codes/idp-infra.git` · GitHub user: `wesley-codes`
- Linux/EKS is **case-sensitive**: the folder is `gitops` (lowercase). Type it exactly.

---

## ONE-TIME SETUP: the GitHub token
ArgoCD reads the private repo with a fine-grained GitHub token: only the `idp-infra` repo,
**Contents: Read-only**. Terraform reads it from the `TF_VAR_github_token` variable.

1. Save the token in the Keychain (paste it only here, never in chat or files):
   ```bash
   security add-generic-password -U -a "$USER" -s idp-github-token -w 'PASTE-TOKEN-HERE'
   ```
2. Load it in every new terminal:
   ```bash
   echo 'export TF_VAR_github_token=$(security find-generic-password -s idp-github-token -w 2>/dev/null)' >> ~/.zshrc
   source ~/.zshrc
   ```
3. Check it (shows only the first 15 characters):
   ```bash
   printenv TF_VAR_github_token | cut -c1-15
   ```

**When the token expires** (or leaks): delete it on GitHub, create a new one with the same
settings, rerun step 1 with the new token, open a new terminal, then `terraform apply`.
Terraform updates the secret inside the cluster.

---

## STEP 1: Build the whole platform
```bash
aws-vault exec terraform --no-session -- $SHELL
cd ~/Documents/idp-infra/environments/dev
terraform apply        # ~15–20 min: VPC, EKS, nodes, then ArgoCD, repo connection, root
```
(If the account-wide pieces were destroyed too, apply `environments/global` first.)

## STEP 2: Point kubectl at the new cluster
Every rebuild gives the cluster a new address, so kubectl's address book needs updating.
Terraform reads the address itself, so it doesn't need this step.
```bash
aws eks update-kubeconfig --name idp-dev-cluster --region us-east-1
kubectl get nodes                  # 2 nodes, Ready
```

## STEP 3: Verify everything came back
```bash
kubectl get applications -n argocd
# expect: root, web, kube-prometheus-stack, loki, alloy → all Synced / Healthy
#         (monitoring can sit in Progressing for a few minutes: it's a big chart)

kubectl get pods -n default        # web pod: 1/1 Running
kubectl get pods -n monitoring     # prometheus, grafana, loki-0, alloy, ... Running
```

## STEP 4: Reach the apps (each opens a private tunnel; leave it running)
```bash
# Your web app
kubectl port-forward svc/web -n default 8081:80
#   → http://localhost:8081

# Grafana: metrics dashboards AND logs        login: admin / admin
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80
#   → http://localhost:3000
#   Logs: Explore → data source "Loki" → Code → {namespace="default"}

# ArgoCD UI                                   login: admin / <password below>
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
kubectl port-forward svc/argocd-server -n argocd 8080:443
#   → https://localhost:8080 (accept the self-signed certificate)
```
If a service name is ever wrong, list them: `kubectl get svc -n <namespace>`.

---

## EVERYDAY: ship a code change (the CI/CD loop)
Change something under `app/`, then:
```bash
git pull --rebase        # get the CI bot's auto-commits first (avoids divergent branches)
git status               # check only the files you meant to change
git add app/
git commit -m "..."
git push
```
The pipeline runs automatically: **Semgrep → build → Trivy scan → push to ECR → write the new
image tag into gitops/web/kustomization.yaml (commit back)**. ArgoCD then pulls the new tag and
deploys it. You never touch the cluster. To rerun it without a code change, click
**Run workflow** on GitHub's Actions tab.

## EVERYDAY: add a new tool to the cluster
Drop a new ArgoCD Application file into `gitops/apps/`, commit and push. Root creates it on its
own. To remove a tool, delete its file and push.

## TEARDOWN: stop the meter when done for the day
```bash
cd ~/Documents/idp-infra/environments/dev
terraform destroy
```
Terraform removes things in reverse order: root app, ArgoCD, then the cluster and network.
Your Git repo is the source of truth: rerun this runbook from STEP 1 to get everything back.

---

## Troubleshooting cheat-sheet
| Symptom | Cause | Fix |
|---|---|---|
| `UnrecognizedClientException` / `security token is invalid` | Ran a command outside aws-vault (no live creds) | Open the aws-vault shell; check with `echo $AWS_VAULT` (should print `terraform`) |
| Terraform asks `var.github_token` on apply or destroy | Token not loaded in this terminal | `printenv TF_VAR_github_token \| cut -c1-15`; if empty, check the Keychain entry and `~/.zshrc` line |
| kubectl: `dial tcp: lookup ... no such host` | kubeconfig still has the old (destroyed) cluster's address | `aws eks update-kubeconfig --name idp-dev-cluster --region us-east-1` |
| ArgoCD Settings → Repositories shows **Failed** | GitHub token expired or was deleted | Create a new token, save it in the Keychain, new terminal, `terraform apply` |
| `terraform apply`: helm release "invalid ownership metadata" | Something was created by hand that Terraform now wants to own | Delete the hand-made copy (e.g. `kubectl delete application root -n argocd`), then apply |
| `ImagePullBackOff` + ECR list is empty | No image pushed for that tag (repo recreated with `force_delete`) | Click **Run workflow** on the Actions tab; the pipeline repopulates ECR and updates the tag |
| `git push` rejected, branches "diverged" | CI bot committed while you had local commits | `git pull --rebase` (set default: `git config pull.rebase true`) |
| `sed: can't read gitops/...` in CI | Folder casing mismatch (`gitOPs` vs `gitops`) | Check `git ls-tree -r origin/main \| grep -i gitops`; rename to lowercase |
| ArgoCD app `Namespace ... is missing` | Manifests have no namespace | Add `namespace: <ns>` to the kustomization.yaml |
| `services "grafana" not found` | Wrong service name | It's `kube-prometheus-stack-grafana` on port `80` |
| Pods `Pending` (Insufficient memory) in monitoring | Nodes too small for the stack | Bump node group size or trim the Helm values |
| Lens asks for "SSO Start URL / username" | You use aws-vault (IAM user), not AWS SSO | Skip SSO; launch Lens via aws-vault so its kubeconfig context has creds, or just use Grafana |
