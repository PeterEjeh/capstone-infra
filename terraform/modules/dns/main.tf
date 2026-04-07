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
