# Operational Runbook

## Prerequisites

All commands assume the following environment variables are set:

```bash
export CLUSTER_NAME="taskapp.taskapp-peter.name.ng"
export KOPS_STATE_STORE="s3://capstone-kops-state-32469f34"
export AWS_ACCESS_KEY_ID="<your-access-key>"
export AWS_SECRET_ACCESS_KEY="<your-secret-key>"
export AWS_DEFAULT_REGION="us-east-1"
```

---

## 1. Deploy the Application from Scratch

### Step 1 — Bootstrap Terraform State Backend
```bash
cd ~/capstone-infra/terraform/backend-bootstrap
terraform init
terraform apply
# Note the s3_bucket_name output
```

### Step 2 — Deploy AWS Infrastructure
```bash
cd ~/capstone-infra/terraform
terraform init
terraform apply
# Save outputs: terraform output > ~/capstone-outputs.txt
```

### Step 3 — Create the Kubernetes Cluster
```bash
# Generate SSH key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/kops_rsa -N ''

# Create cluster spec
kops create cluster \
  --name=${CLUSTER_NAME} \
  --state=${KOPS_STATE_STORE} \
  --kubernetes-version=1.28.4 \
  --control-plane-count=3 \
  --control-plane-size=t3.medium \
  --node-count=3 \
  --node-size=t3.medium \
  --zones=us-east-1a,us-east-1b,us-east-1c \
  --control-plane-zones=us-east-1a,us-east-1b,us-east-1c \
  --networking=calico \
  --topology=private \
  --bastion \
  --ssh-public-key=~/.ssh/kops_rsa.pub \
  --cloud=aws \
  --dns-zone=${CLUSTER_NAME} \
  --network-id=<vpc-id> \
  --subnets=<private-subnet-1>,<private-subnet-2>,<private-subnet-3> \
  --utility-subnets=<public-subnet-1>,<public-subnet-2>,<public-subnet-3>

# Apply cluster
kops update cluster --name=${CLUSTER_NAME} --state=${KOPS_STATE_STORE} --yes --admin

# Wait and validate (10-15 minutes)
kops validate cluster --name=${CLUSTER_NAME} --state=${KOPS_STATE_STORE} --wait 15m
```

### Step 4 — Install Cluster Add-ons
```bash
# StorageClass (gp3)
kubectl apply -f ~/capstone-infra/k8s/storageclass.yaml

# NGINX Ingress
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.replicaCount=2

# cert-manager
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set installCRDs=true

# Sealed Secrets
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm install sealed-secrets sealed-secrets/sealed-secrets \
  --namespace kube-system \
  --set fullnameOverride=sealed-secrets-controller
```

### Step 5 — Deploy Application
```bash
kubectl apply -f ~/capstone-infra/k8s/

# Initialize database
kubectl exec -n taskapp deploy/taskapp-backend -- python -c "
from app import create_app, db
from app.models import User
from werkzeug.security import generate_password_hash
app = create_app()
with app.app_context():
    db.create_all()
    if User.query.count() == 0:
        admin = User(username='admin', password_hash=generate_password_hash('admin123'))
        db.session.add(admin)
        db.session.commit()
        print('Database initialized')
"
```

---

## 2. Scale the Cluster

### Scale Worker Nodes
```bash
# Edit the instance group
kops edit ig nodes-us-east-1a --name=${CLUSTER_NAME} --state=${KOPS_STATE_STORE}
# Change minSize and maxSize values

# Apply the change
kops update cluster --name=${CLUSTER_NAME} --state=${KOPS_STATE_STORE} --yes
kops rolling-update cluster --name=${CLUSTER_NAME} --state=${KOPS_STATE_STORE} --yes
```

### Scale Application Pods
```bash
# Scale frontend
kubectl scale deployment taskapp-frontend -n taskapp --replicas=3

# Scale backend
kubectl scale deployment taskapp-backend -n taskapp --replicas=3

# Verify
kubectl get pods -n taskapp
```

---

## 3. Rotate Secrets

### Rotate Database Password
```bash
# 1. Update the password in PostgreSQL
kubectl exec -n taskapp deploy/postgres -- psql -U taskapp_user -d taskapp \
  -c "ALTER USER taskapp_user WITH PASSWORD 'new-password';"

# 2. Create new sealed secret
kubectl create secret generic taskapp-secret \
  --namespace taskapp \
  --from-literal=DATABASE_PASSWORD=new-password \
  --dry-run=client -o yaml | \
  kubeseal --format yaml \
    --controller-name=sealed-secrets \
    --controller-namespace=kube-system \
  > ~/capstone-infra/k8s/sealed-secret.yaml

# 3. Apply and restart backend
kubectl apply -f ~/capstone-infra/k8s/sealed-secret.yaml
kubectl rollout restart deployment/taskapp-backend -n taskapp
```

### Rotate AWS Access Keys
```bash
# 1. Create new key in AWS IAM console
# 2. Update environment variables
export AWS_ACCESS_KEY_ID="new-key-id"
export AWS_SECRET_ACCESS_KEY="new-secret"

# 3. Update ~/.bashrc
echo "export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID" >> ~/.bashrc
echo "export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY" >> ~/.bashrc

# 4. Delete old key in AWS IAM console
```

---

## 4. Troubleshooting Common Failures

### Cluster Not Validating
```bash
# Check node status
kubectl get nodes
kubectl describe node <node-name>

# Check system pods
kubectl get pods -n kube-system

# Re-export kubeconfig
kops export kubecfg --name=${CLUSTER_NAME} --state=${KOPS_STATE_STORE} --admin
```

### Pod CrashLoopBackOff
```bash
# Check logs
kubectl logs -n taskapp <pod-name> --previous

# Describe pod for events
kubectl describe pod -n taskapp <pod-name>

# Check resource limits
kubectl top pods -n taskapp
```

### Database Connection Error
```bash
# Verify postgres is running
kubectl get pods -n taskapp | grep postgres

# Test connection from backend
kubectl exec -n taskapp deploy/taskapp-backend -- python -c "
import psycopg2
conn = psycopg2.connect('postgresql://taskapp_user:taskapp_password@postgres:5432/taskapp')
print('Connected successfully')
"

# Check env vars are set
kubectl exec -n taskapp deploy/taskapp-backend -- env | grep DATABASE
```

### SSL Certificate Not Issuing
```bash
# Check certificate status
kubectl get certificate -n taskapp
kubectl describe certificate taskapp-tls -n taskapp

# Check cert-manager logs
kubectl logs -n cert-manager deploy/cert-manager | tail -30

# Check challenge
kubectl get challenge -n taskapp
```

### Ingress Not Routing
```bash
# Check ingress rules
kubectl describe ingress taskapp -n taskapp

# Check NGINX pods
kubectl get pods -n ingress-nginx

# Check service endpoints
kubectl get endpoints -n taskapp
```

### S3 Dualstack Connection Error (WSL)
```bash
# Disable IPv6 dualstack
aws configure set default.s3.use_dualstack_endpoint false
aws configure set default.s3.addressing_style virtual
```

---

## 5. Backup and Restore

### etcd Backups
etcd backups are automated by kops etcd-manager with 90-day retention to S3:
```bash
# List backups
aws s3 ls s3://capstone-kops-state-32469f34/${CLUSTER_NAME}/backups/etcd/
```

### Database Backup
```bash
# Manual backup
kubectl exec -n taskapp deploy/postgres -- \
  pg_dump -U taskapp_user taskapp > ~/taskapp-backup-$(date +%Y%m%d).sql

# Copy backup to S3
aws s3 cp ~/taskapp-backup-$(date +%Y%m%d).sql \
  s3://capstone-kops-state-32469f34/db-backups/
```

### Database Restore
```bash
# Copy backup from S3
aws s3 cp s3://capstone-kops-state-32469f34/db-backups/taskapp-backup-YYYYMMDD.sql ~/

# Restore
cat ~/taskapp-backup-YYYYMMDD.sql | \
  kubectl exec -i -n taskapp deploy/postgres -- \
  psql -U taskapp_user taskapp
```

---

## 6. Destroy Infrastructure

```bash
# Step 1 — Delete Kubernetes workloads
kubectl delete -f ~/capstone-infra/k8s/

# Step 2 — Delete cluster
kops delete cluster --name=${CLUSTER_NAME} --state=${KOPS_STATE_STORE} --yes

# Step 3 — Destroy Terraform infrastructure
cd ~/capstone-infra/terraform
terraform destroy

# Step 4 — Destroy backend (optional — deletes state)
cd ~/capstone-infra/terraform/backend-bootstrap
terraform destroy
```

> ⚠ Warning: Step 4 will delete your Terraform state. Only run if you are fully done with the project.
