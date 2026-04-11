# Architecture Documentation

## Project Overview

**Project:** Cloud-Native TaskApp on AWS  
**Domain:** taskapp.taskapp-peter.name.ng  
**Stack:** AWS + Terraform + Kops + Kubernetes 1.28 + Docker  
**Region:** us-east-1 (N. Virginia)

---

## System Architecture Diagram

```
Internet
    │
    ▼
Route53 (taskapp-peter.name.ng)
    │
    ▼
AWS Network Load Balancer (NGINX Ingress)
    │
    ├── / ──────────────▶ taskapp-frontend (nginx, port 80)
    └── /api ───────────▶ taskapp-backend  (Flask, port 5000)
                                │
                                ▼
                         postgres (PostgreSQL, port 5432)
                                │
                                ▼
                         EBS Volume (gp3, encrypted)

┌─────────────────────────────────────────────────────────┐
│  VPC: 10.0.0.0/16                                       │
│                                                         │
│  Public Subnets (Utility)                               │
│  ├── us-east-1a: 10.0.0.0/20  (NAT GW, Bastion, NLB)  │
│  ├── us-east-1b: 10.0.1.0/20  (NAT GW, NLB)           │
│  └── us-east-1c: 10.0.2.0/20  (NAT GW, NLB)           │
│                                                         │
│  Private Subnets (Nodes)                                │
│  ├── us-east-1a: 10.0.3.0/20  (Control Plane + Node)  │
│  ├── us-east-1b: 10.0.4.0/20  (Control Plane + Node)  │
│  └── us-east-1c: 10.0.5.0/20  (Control Plane + Node)  │
└─────────────────────────────────────────────────────────┘
```

---

## CIDR Allocation Rationale

| Subnet | CIDR | Purpose | Size |
|--------|------|---------|------|
| VPC | 10.0.0.0/16 | Entire network | 65,536 IPs |
| Public us-east-1a | 10.0.0.0/20 | NAT GW, Load Balancers | 4,096 IPs |
| Public us-east-1b | 10.0.1.0/20 | NAT GW, Load Balancers | 4,096 IPs |
| Public us-east-1c | 10.0.2.0/20 | NAT GW, Load Balancers | 4,096 IPs |
| Private us-east-1a | 10.0.3.0/20 | K8s nodes | 4,096 IPs |
| Private us-east-1b | 10.0.4.0/20 | K8s nodes | 4,096 IPs |
| Private us-east-1c | 10.0.5.0/20 | K8s nodes | 4,096 IPs |

**Justification:** /16 VPC provides room for future growth. /20 subnets give 4,096 IPs per subnet which is sufficient for Kubernetes pod CIDR allocation via Calico CNI. The large subnet sizes prevent IP exhaustion as Kubernetes assigns IPs to pods, not just nodes.

---

## High Availability Strategy

### Control Plane HA
- 3 control plane nodes distributed across 3 AZs (us-east-1a, 1b, 1c)
- etcd runs in distributed quorum — survives loss of 1 master (floor(3/2) = 1 tolerated failure)
- etcd backups automated to S3 with 90-day retention

### Worker Node HA
- 3 worker nodes distributed across 3 AZs
- Kubernetes scheduler spreads pods across nodes by default
- Pod Disruption Budgets prevent all replicas going down during maintenance

### Network HA
- 3 NAT Gateways (one per AZ) — no single point of failure for outbound traffic
- AWS NLB spans all 3 AZs automatically
- Calico CNI handles pod-to-pod networking with NetworkPolicy support

### Application HA
- Frontend: 2 replicas minimum
- Backend: 2 replicas minimum
- Rolling update strategy with maxUnavailable=0

---

## Security Model

### Network Security
- All Kubernetes nodes in private subnets — no public IPs on any node
- Internet access for nodes via NAT Gateways only
- Bastion host in public subnet for emergency SSH access
- Security groups follow least-privilege (specific ports only)

### IAM Security
- Dedicated `kops-operator` IAM user for cluster operations (not root)
- EC2 instance profiles for node-level AWS API access
- No hardcoded AWS credentials in any code or container

### Secret Management
- Bitnami Sealed Secrets encrypts Kubernetes secrets at rest
- Sealed secrets are safe to commit to Git (asymmetric encryption)
- Database credentials never appear in plaintext in the repository
- Kubernetes etcd encrypted at rest (encryptedVolume: true on etcd members)

### TLS/SSL
- cert-manager automates Let's Encrypt certificate issuance
- Certificates auto-renew before expiry (cert-manager handles rotation)
- HTTP traffic redirected to HTTPS via NGINX ingress annotation
- TLS terminates at the ingress controller

---

## Infrastructure as Code

### Terraform Module Structure
```
terraform/
├── backend-bootstrap/     # S3 bucket + DynamoDB lock table
├── modules/
│   ├── vpc/               # VPC, subnets, NAT gateways, route tables
│   ├── dns/               # Route53 hosted zones + DNS records
│   └── iam/               # kops-operator IAM user + policies
├── backend.tf             # Remote state config (S3 + DynamoDB)
└── main.tf                # Root module wiring all sub-modules
```

### State Management
- Remote state stored in S3 bucket with versioning enabled
- State locking via DynamoDB (prevents concurrent modifications)
- State encrypted at rest (AES256)

---

## Kubernetes Cluster Specifications

| Parameter | Value |
|-----------|-------|
| Kubernetes Version | 1.28.4 |
| Cluster Manager | Kops 1.28.4 |
| CNI | Calico |
| Topology | Private |
| Control Plane Nodes | 3 x t3.medium |
| Worker Nodes | 3 x t3.medium |
| Storage Class | gp3 (default, encrypted) |
| Ingress | NGINX Ingress Controller |
| SSL | cert-manager + Let's Encrypt |
| Secrets | Bitnami Sealed Secrets |

---

## Application Architecture

### Frontend (React + Vite + Tailwind)
- 2 replicas running behind NGINX
- Served as static files via nginx:alpine container
- Routes: `/` serves the React SPA

### Backend (Python Flask)
- 2 replicas running Flask development server
- JWT-based authentication
- Routes: `/api/*` for all API endpoints
- Connects to PostgreSQL via internal Kubernetes DNS

### Database (PostgreSQL 15)
- 1 replica with persistent EBS volume
- Internal service only — not exposed outside the cluster
- Data persists through pod restarts via PersistentVolumeClaim

### DNS Flow
```
User → taskapp.taskapp-peter.name.ng
     → Route53 (taskapp.taskapp-peter.name.ng zone)
     → AWS NLB (NGINX Ingress)
     → / → taskapp-frontend service → frontend pods
     → /api → taskapp-backend service → backend pods
                                      → postgres service → DB pod
```
