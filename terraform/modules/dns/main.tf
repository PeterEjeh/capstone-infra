resource "aws_route53_zone" "main" {
  name = var.domain_name
  tags = { Name = "${
		var.project_name}-zone" 
		Project = var.project_name 

}
}

# Kops state store S3 bucket (separate from Terraform state)
resource "aws_s3_bucket" "kops_state" {
  bucket = "${var.project_name}-kops-state-${substr(md5(var.domain_name),0,8)}"
  tags   = { Name = "kops-state" }
}

resource "aws_s3_bucket_versioning" "kops_state" {
  bucket = aws_s3_bucket.kops_state.id
  versioning_configuration { status = "Enabled" }
}

variable "ingress_hostname" {
  description = "ELB hostname from NGINX ingress"
  type        = string
  default     = ""
}


data "aws_route53_zone" "kops_subdomain" {
  name         = "taskapp.${var.domain_name}"
  private_zone = false
}

data "aws_elb_hosted_zone_id" "main" {}

resource "aws_route53_record" "taskapp" {
  count   = var.ingress_hostname != "" ? 1 : 0
  zone_id = data.aws_route53_zone.kops_subdomain.zone_id
  name    = "taskapp.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.ingress_hostname
    zone_id                = data.aws_elb_hosted_zone_id.main.id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "api" {
  count   = var.ingress_hostname != "" ? 1 : 0
  zone_id = data.aws_route53_zone.kops_subdomain.zone_id
  name    = "api.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.ingress_hostname
    zone_id                = data.aws_elb_hosted_zone_id.main.id
    evaluate_target_health = true
  }
}
