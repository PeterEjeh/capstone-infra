output "zone_id"          { value = aws_route53_zone.main.zone_id }
output "nameservers"      { value = aws_route53_zone.main.name_servers }
output "kops_state_bucket"{ value = aws_s3_bucket.kops_state.bucket }
