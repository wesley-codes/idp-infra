# Phase 1 — Networking explained (the VPC, in plain terms)

The whole network is one idea: **public rooms are reachable and hold the doors; private
rooms are hidden and borrow outbound-only access through a NAT.** Everything else is
plumbing that makes that work.

Analogy: the VPC is a **walled compound**. Subnets are **rooms**. Some rooms have a street
door (public), some don't (private). The rest of the pieces are doors and signposts.

## Every resource, in plain terms

| Terraform resource | What it really is | Why it's there |
|---|---|---|
| `aws_vpc.this` | The walled compound — your private network (`10.0.0.0/16`) | An isolated space on AWS where everything lives; nothing outside wanders in |
| `aws_subnet.public[0,1]` | Public rooms (one per AZ) | Where internet-facing things sit — load balancers and the NAT |
| `aws_subnet.private[0,1]` | Private rooms (one per AZ) | Where app servers / EKS nodes live, hidden from the internet |
| `aws_internet_gateway.this` | The front door to the public internet | The compound's one connection to the outside world |
| `aws_route_table.public` | A signpost board for public rooms | Holds directions for traffic leaving public rooms |
| `aws_route.public_internet` | The sign: "internet (`0.0.0.0/0`) → front door (IGW)" | Tells public rooms how to reach the internet |
| `aws_route_table_association.public[0,1]` | Bolting that board onto each public room | A signpost does nothing until it's hung in the room |
| `aws_eip.nat` | A permanent public address for the mailroom | The NAT needs a fixed public IP so replies find their way back |
| `aws_nat_gateway.this` | The one-way mailroom (sits in a public room) | Lets private rooms send mail *out*, blocks anyone sending *in* |
| `aws_route_table.private` | A signpost board for private rooms | Holds directions for traffic leaving private rooms |
| `aws_route.private_nat` | The sign: "internet → mailroom (NAT)" | Tells private rooms to reach the internet only via the NAT |
| `aws_route_table_association.private[0,1]` | Bolting that board onto each private room | Hangs the private signpost in both private rooms |

## Follow two journeys

**Journey 1 — a user on the internet visits your app**
```
internet ──▶ IGW (front door) ──▶ load balancer (public room) ──▶ app (private room)
```
The outside world only ever touches the public-facing load balancer — never your nodes.

**Journey 2 — a private node pulls a container image (outbound only)**
```
node (private room) ──▶ NAT (public room) ──▶ IGW ──▶ internet ──▶ (reply comes back same path)
```
This path works outbound only. Nobody on the internet can start a conversation with the
node, because no signpost points inward to it.

## Key rules to remember
- A subnet is only truly "public" when its route table sends `0.0.0.0/0` to an **internet
  gateway**. The name/tag doesn't make it public — the route does.
- The NAT must live in a **public** subnet, because the NAT itself needs the IGW route to
  reach the internet.
- Public route uses `gateway_id` (IGW); private route uses `nat_gateway_id` (NAT). Different
  attribute for a different gateway.
- Dev uses **one shared NAT** to save money (~$1/day). Prod would use one NAT per AZ for
  resilience.

