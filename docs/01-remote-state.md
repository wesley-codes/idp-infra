# Phase 1a — Terraform remote state (the shared, locked memory)

## What "state" is
Terraform keeps a **state file** — its memory/map linking each line of your code to the
real AWS resource it created. It's how Terraform knows "I already made that VPC, don't
make a second one."

```
   your .tf code   ──apply──▶   real AWS resources (VPC, EKS, ...)
        │                              │
        └──────────▶   STATE FILE  ◀───┘
                     (map: code ↔ real resource)
```

## Why store it remotely (S3)
By default the state file sits on your laptop — fragile (lose the laptop, lose the map)
and unreachable by CI/CD. We store it in an **S3 bucket**: a durable, shared filing
cabinet in the cloud. Bucket settings we apply:
- **Versioning on** — keep old copies so a bad apply can be rolled back.
- **All public access blocked** — state can contain secrets.
- **Encryption at rest** — AES-256 by default.

## Why a lock (DynamoDB)
If two `apply` runs overlap (your laptop + CI, or two terminals), they can both write the
map and the second overwrites the first → the map no longer matches reality. A **lock**
forces them to take turns — like an "occupied" sign on a door. Terraform stores that lock
in a small **DynamoDB** table whose key must be named `LockID`.

> Note: Terraform 1.9.x uses DynamoDB for locking. Terraform 1.10+ can lock using S3
> alone (`use_lockfile = true`) — a nice "if I upgrade" footnote.

## The chicken-and-egg
Terraform stores state in S3, but S3 is normally created *by* Terraform. To break the
loop we create the bucket + lock table **once** with plain CLI commands
(`bootstrap/create-backend.sh`), then point Terraform's backend at them.

## One bucket, many environments
The same bucket holds dev/stage/prod state, separated by the `key` path in each
environment's `backend.tf`:
- `environments/dev/backend.tf`   → `key = "dev/terraform.tfstate"`
- `environments/stage/backend.tf` → `key = "stage/terraform.tfstate"`
- `environments/prod/backend.tf`  → `key = "prod/terraform.tfstate"`

## Cost
Effectively free: an empty S3 bucket + a pay-per-request DynamoDB table cost pennies.
