module "vpc" {
  source       = "./modules/vpc"
  vpc_cidr     = "10.0.0.0/16"
  project_name = "capstone"
  azs          = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

module "dns" {
  source       = "./modules/dns"
  domain_name  = "taskapp-peter.name.ng"
  project_name = "capstone"
}

module "iam" {
  source = "./modules/iam"
}

# ── Outputs ─────────────────────────────
output "vpc_id"             { value = module.vpc.vpc_id }
output "public_subnet_ids"  { value = module.vpc.public_subnet_ids }
output "private_subnet_ids" { value = module.vpc.private_subnet_ids }
output "nameservers"        { value = module.dns.nameservers }
output "kops_state_bucket"  { value = module.dns.kops_state_bucket }
output "kops_access_key"    { value = module.iam.kops_access_key_id }
