# idp-infra — Internal Developer Platform

A self-service Internal Developer Platform (IDP): a Kubernetes-based platform other
engineers can deploy applications onto — provisioned entirely through code, observed
end-to-end, and secured by policy.

The goal is platform-level ownership: not "I deployed an app," but "I built the golden
path other engineers deploy on."

## Build phases

| # | Phase | Tools |
|---|-------|-------|
| 0 | Prerequisites & foundations | AWS account, IAM, aws-vault, AWS CLI, Terraform, kubectl, Helm |
| 1 | Infrastructure as Code | Terraform, AWS (VPC, EKS, IAM, S3 + DynamoDB state) |
| 2 | Container orchestration | Amazon EKS, (optional OKD), kubectl, Helm |
| 3 | GitOps delivery | ArgoCD, Kustomize |
| 4 | CI/CD pipelines | GitHub Actions, Trivy, Semgrep |
| 5 | Observability | Prometheus, Grafana, ELK (Elasticsearch/Logstash/Kibana) |
| 6 | Security & policy as code | OPA/Gatekeeper or Kyverno, HashiCorp Vault, RBAC |
| 7 | Self-service developer portal | Backstage |
| 8 | SRE practices | Alertmanager, Grafana SLO dashboards, runbooks, (optional Litmus) |
| 9 | (optional) Cost & data pipeline | dbt, SQL, Grafana/BI |

## Repository layout

```
idp-infra/
├── README.md               # this file
├── docs/                   # plain-language notes on each phase / decision
│   ├── 00-prerequisites.md
│   └── 01-remote-state.md
├── bootstrap/              # one-time setup run BEFORE Terraform manages state
│   └── create-backend.sh   # creates the S3 state bucket + DynamoDB lock table
├── modules/                # reusable Terraform building blocks (vpc, eks, ...)
└── environments/           # per-environment stacks that wire modules together
    ├── dev/
    │   └── backend.tf      # points Terraform state at the S3 bucket + lock table
    ├── stage/
    └── prod/
```

## Cost discipline

Real AWS infrastructure costs money (EKS control plane ~$0.10/hr + nodes + NAT).
Workflow: spin up when working, `terraform destroy` when done. A billing budget alert
is the safety net.

## How to work in this repo

1. Credentials are stored in **aws-vault** (never in plaintext). Prefix AWS commands with
   `aws-vault exec terraform -- <command>`.
2. Bootstrap the state backend once: `aws-vault exec terraform -- bash bootstrap/create-backend.sh`
3. Fill in `environments/dev/backend.tf`, then `terraform init` inside that folder.
