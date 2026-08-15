# Phase 0 — Prerequisites & foundations

Plain-language record of the setup done before any infrastructure was built.

## What we set up and why

### 1. Billing budget alert (the smoke alarm)
AWS bills by the hour and won't warn you by default. A **Budget alert** emails you when
spending crosses thresholds (e.g. 50% / 80% / 100% of a monthly cap). It doesn't stop
spending — it's a smoke alarm, not a sprinkler. The real cost control is running
`terraform destroy` at the end of each work session.

### 2. A safe AWS identity (not root)
Daily work should never use the AWS root account. We created a dedicated IAM user
(`terraform`) and stored its access keys in **aws-vault**, which keeps them in the OS
keychain and hands out short-lived temporary credentials — so secret keys are never
sitting in plaintext on disk. Every AWS command is run as:

```
aws-vault exec terraform -- <command>
```

**Policies attached (pragmatic, for a learning build):** `PowerUserAccess` +
`IAMFullAccess`. PowerUser = manage almost every service *except* users/permissions;
IAMFullAccess adds users/permissions back. Terraform needs IAM permissions because
building EKS creates IAM roles (cluster role, node role, OIDC provider).

> ⚠️ Refinement (tracked): this is close to full admin. The senior/production version is
> **least privilege** — scope down to only the IAM actions EKS actually needs. Good
> interview talking point: "I built fast with broad permissions, then scoped the
> automation identity down."

### 3. Local toolchain
Confirmed installed: AWS CLI v2, Terraform (pinned version), kubectl (+ Kustomize
bundled), Helm v3.

## Decisions
- **Environment:** real AWS EKS, spin-up / tear-down between sessions to control cost.
