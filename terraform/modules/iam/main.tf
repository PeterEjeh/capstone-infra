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

resource "aws_iam_user_policy" "kops_eventbridge" {
  name = "kops-eventbridge"
  user = aws_iam_user.kops.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "events:ListRules",
          "events:ListTargetsByRule",
          "events:ListTagsForResource",
          "events:PutRule",
          "events:PutTargets",
          "events:DeleteRule",
          "events:RemoveTargets",
          "events:DescribeRule",
	  "events:TagResource",
          "events:UntagResource"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_user_policy" "kops_sqs" {
  name = "kops-sqs"
  user = aws_iam_user.kops.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ListQueues",
          "sqs:CreateQueue",
          "sqs:DeleteQueue",
          "sqs:GetQueueAttributes",
          "sqs:SetQueueAttributes",
          "sqs:ListQueueTags",
          "sqs:TagQueue"
        ]
        Resource = "*"
      }
    ]
  })
}
