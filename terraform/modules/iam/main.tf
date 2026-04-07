resource "aws_iam_user" "kops" { name = "kops-operator" }

locals {
  kops_policies = [
    "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
    "arn:aws:iam::aws:policy/AmazonRoute53FullAccess",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/IAMFullAccess",
    "arn:aws:iam::aws:policy/AmazonVPCFullAccess",
  ]
}

resource "aws_iam_user_policy_attachment" "kops" {
  for_each   = toset(local.kops_policies)
  user       = aws_iam_user.kops.name
  policy_arn = each.value
}

resource "aws_iam_access_key" "kops" {
  user = aws_iam_user.kops.name
}
