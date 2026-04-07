output "kops_access_key_id" {
  value     = aws_iam_access_key.kops.id
  sensitive = false
}

output "kops_secret_access_key" {
  value     = aws_iam_access_key.kops.secret
  sensitive = true
}
