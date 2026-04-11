# Cost Analysis — Cloud-Native TaskApp on AWS

## Overview

**Region:** us-east-1 (N. Virginia)  
**Duration:** 2 weeks (14 days)  
**Architecture:** Private Kubernetes cluster with 3 control-plane + 3 worker nodes

---

## Weekly Cost Breakdown

### Compute (EC2)

| Resource | Instance Type | Count | Hourly Rate | Daily Cost | Weekly Cost |
|----------|--------------|-------|-------------|------------|-------------|
| Control Plane Nodes | t3.medium | 3 | $0.0416/hr | $3.00 | $20.98 |
| Worker Nodes | t3.medium | 3 | $0.0416/hr | $3.00 | $20.98 |
| Bastion Host | t3.micro | 1 | $0.0104/hr | $0.25 | $1.75 |
| **Compute Total** | | | | **$6.25** | **$43.71** |

### Networking

| Resource | Count | Hourly Rate | Daily Cost | Weekly Cost |
|----------|-------|-------------|------------|-------------|
| NAT Gateway (per AZ) | 3 | $0.045/hr | $3.24 | $22.68 |
| NAT Gateway Data Processing | ~10GB/day | $0.045/GB | $0.45 | $3.15 |
| Network Load Balancer | 1 | $0.008/hr | $0.19 | $1.34 |
| NLB Data Processing | ~5GB/day | $0.006/GB | $0.03 | $0.21 |
| **Networking Total** | | | **$3.91** | **$27.38** |

### Storage (EBS)

| Resource | Size | Count | Rate | Daily Cost | Weekly Cost |
|----------|------|-------|------|------------|-------------|
| Node Root Volumes (gp3) | 64GB | 6 | $0.08/GB/mo | $1.02 | $7.17 |
| PostgreSQL Data Volume (gp3) | 20GB | 1 | $0.08/GB/mo | $0.05 | $0.38 |
| **Storage Total** | | | | **$1.07** | **$7.55** |

### DNS & Other

| Resource | Rate | Daily Cost | Weekly Cost |
|----------|------|------------|-------------|
| Route53 Hosted Zone (x2) | $0.50/mo each | $0.03 | $0.23 |
| Route53 DNS Queries | $0.40/million | $0.01 | $0.07 |
| S3 (State + Kops) | ~$0.023/GB/mo | $0.01 | $0.07 |
| **DNS & Other Total** | | **$0.05** | **$0.37** |

---

## Total Cost Summary

| Category | Daily Cost | Weekly Cost | 2-Week Total |
|----------|------------|-------------|--------------|
| Compute (EC2) | $6.25 | $43.71 | $87.42 |
| Networking (NAT + NLB) | $3.91 | $27.38 | $54.76 |
| Storage (EBS) | $1.07 | $7.55 | $15.10 |
| DNS & Other | $0.05 | $0.37 | $0.74 |
| **TOTAL** | **$11.28** | **$78.99** | **$158.02** |

> ⚠ These are estimates based on AWS us-east-1 pricing as of April 2026. Actual costs may vary based on data transfer and usage patterns.

---

## Cost Optimization Recommendations

### Immediate Savings
1. **Spot Instances for Worker Nodes** — Replace on-demand worker nodes with spot instances for ~70% savings on compute
   - Estimated saving: ~$29/week on workers
   - Risk: Spot interruptions (mitigated by multi-AZ deployment)

2. **Single NAT Gateway** — Replace 3 NAT Gateways with 1 for non-HA dev environments
   - Estimated saving: ~$15/week
   - Risk: Single point of failure for outbound traffic

3. **t3.small for Workers** — Downsize worker nodes if workload allows
   - Estimated saving: ~$10/week

### Shutdown Strategy (Cost Control During Development)
```bash
# Tear down cluster at night (saves ~$9/hour)
kops delete cluster --name=${CLUSTER_NAME} --yes

# Recreate next morning (~15 min to rebuild)
kops update cluster --name=${CLUSTER_NAME} --yes --admin
kops validate cluster --wait 15m
```

**Note:** VPC, Route53, and S3 can remain running — they cost ~$0.08/day combined.

---

## Budget Alert Configuration

A $50 monthly budget alert was configured via AWS Budgets:

```bash
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget '{"BudgetName":"capstone-limit","BudgetLimit":{"Amount":"50","Unit":"USD"},"TimeUnit":"MONTHLY","BudgetType":"COST"}' \
  --notifications-with-subscribers \
  '[{"Notification":{"NotificationType":"ACTUAL","ComparisonOperator":"GREATER_THAN","Threshold":80},"Subscribers":[{"SubscriptionType":"EMAIL","Address":"peterejeh09@gmail.com"}]}]'
```

Alert triggers at 80% ($40) of the $50 monthly limit.

---

## Bonus: Cost vs. Managed Alternatives

| Solution | Monthly Cost | Managed | HA |
|----------|-------------|---------|-----|
| This project (Kops) | ~$316 | No | Yes |
| AWS EKS (3 nodes) | ~$220 | Yes | Yes |
| AWS EKS + Fargate | ~$180 | Fully | Yes |
| AWS RDS (db.t3.micro) | +$15/mo | Yes | Optional |

> EKS would be cheaper and fully managed in production. Kops was chosen here for learning cluster operations at a deeper level.
