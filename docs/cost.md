# Cost model

Prices move and vary by contract. Treat this as an order-of-magnitude model, then
confirm in the OCI cost estimator before applying. The point is to know which
resources burn credit and to destroy them when evidence is captured.

## What is free or nearly free

- VCN, subnets, gateways, security lists, NSGs, route tables.
- OCI Bastion (standard, sessions are short-lived).
- OCI Monitoring alarms, ONS email topic, Logging within the free allowance.
- OCIR storage for a small image (first 500 MB is free-tier eligible).
- Vault: one key version and a small secret are inexpensive but not zero.

## What costs money

Approximate on-demand rates for `us-ashburn-1`, used only for planning:

| Resource | Assumption | Rate (approx.) | Monthly |
|---|---|---|---|
| E5 Flex app VM | 1 OCPU / 8 GB | $0.0375/hr | ~$27 |
| Ops runner | 1 OCPU / 8 GB | $0.0375/hr | ~$27 |
| OKE worker | 2 OCPU / 16 GB | $0.075/hr | ~$54 |
| Flexible LB | 10 Mbps minimum | ~$0.03/hr | ~$22 |
| Block volumes | 50 GB × 3 + 100 GB + 50 GB | $0.0255/GB-month | ~$8 |
| ADB | 2 ECPU / 20 GB (ECPU model) | billed hourly, not free | see OCI price list |
| Object Storage | < 5 GB, infrequent | ~$0.0255/GB | < $1 |
| Vault key | software key, 1 version | small | ~$1 |

Dev defaults (2 app VMs, 1 ops runner, 1 OKE node, LB) land around **$5/day**,
roughly **$150–170/month** if left running.

Prod defaults (3 app VMs, 2 OKE nodes) land around **$7/day**, roughly
**$210–230/month**.

A $200 credit therefore buys weeks of a full stack, or months of a reduced stack.
It does not buy a year. Destroy when the evidence is captured.

## Cheapest useful configurations

| Goal | Settings | Approx. burn |
|---|---|---|
| Terraform + Ansible + LB only | `enable_oke=false`, `enable_adb=false`, 1 app VM | ~$2/day |
| Add containers | `enable_oke=true`, 1 node | ~$4/day |
| Full demo | defaults | ~$5/day |
| Prod-shaped | 3 app VMs, 2 nodes | ~$7/day |

ADB is not free in this stack. New Autonomous Databases must use the ECPU compute
model (the OCPU model is rejected), so the smallest instance is 2 ECPUs and 20 GB
and it bills from creation. Set `enable_adb=false` for the cheapest demo.

Compute shape matters as much as size. This tenancy's `standard-e4-core-count` is
zero, so anything on `VM.Standard.E4.Flex` fails with `400-LimitExceeded`. The
presets use `VM.Standard.E5.Flex`, which has capacity and is the only family OKE
offers for its node images here.

## Guardrails in code

- `modules/budget` creates a monthly compartment budget with actual-spend alerts
  (default thresholds from `variables.tf`).
- The budget is a notification, not a hard stop. OCI does not pause resources
  automatically.
- A budget scoped to an existing compartment may fire immediately because it
  includes prior spend. Scope it to the new platform compartment or raise the
  amount.

## Cost hygiene checklist

- [ ] `terraform destroy` after screenshots and evidence capture.
- [ ] Confirm the OKE node pool and both load balancers are gone.
- [ ] Confirm ADB is terminated (it can take several minutes).
- [ ] Empty and delete evidence buckets if they are no longer needed.
- [ ] Delete the Vault and key only after the secret is no longer required.
- [ ] Check **Billing & Cost Management** the next day for residual block volumes.
- [ ] Delete unused OCIR images.
