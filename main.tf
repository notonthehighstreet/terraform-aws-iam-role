// Current AWS identity (useful for AWS account_id)
data "aws_caller_identity" "identity" {}

// Create instance profile when service is ec2
resource "aws_iam_instance_profile" "instance-profile" {
  count = var.enabled && var.allow_service == "ec2.amazonaws.com" ? 1 : 0
  name  = aws_iam_role.role[0].name
  role  = aws_iam_role.role[0].name
}

// Create a role
resource "aws_iam_role" "role" {
  count                = var.enabled ? 1 : 0
  name                 = var.name
  max_session_duration = var.max_session_duration
  path                 = var.path

  tags = merge(
    var.tags, {
      "Name" = var.name
  })

  assume_role_policy = length(compact(var.allow_arn)) > 0 ? data.aws_iam_policy_document.access-policy-arn[0].json : data.aws_iam_policy_document.access-policy-service[0].json
}

// Defines who is able to access the role (Prinicapls)
data "aws_iam_policy_document" "access-policy-service" {
  count = var.enabled && length(var.allow_service) > 0  ? 1 : 0

  statement {
    sid = "AllowService"

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type = "Service"

      identifiers = [
        var.allow_service,
      ]
    }

    effect = "Allow"
  }
}

data "aws_iam_policy_document" "access-policy-arn" {
  count = var.enabled ? 1 : 0

  statement {
    sid     = "AllowARN"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = var.allow_arn
    }

    effect = "Allow"

    condition {
      test = "StringEqualsIfExists"
      values = [
        var.external_id
      ]
      variable = "sts:ExternalId"
    }

    //    condition {
    //      test = "BoolIfExists"
    //      values = ["true"]
    //      variable = "aws:MultiFactorAuthPresent"
    //    }
  }
}

// Defines what roles this role is able to assume
resource "aws_iam_role_policy" "assume-policy" {
  count  = var.enabled && length(compact(var.assume_role)) > 0 ? 1 : 0
  name   = "assume-policy"
  policy = data.aws_iam_policy_document.assume-policy[0].json
  role   = aws_iam_role.role[0].id
}

data "aws_iam_policy_document" "assume-policy" {
  count = var.enabled && length(compact(var.assume_role)) > 0 ? 1 : 0

  statement {
    sid       = "AssumeRole"
    actions   = ["sts:AssumeRole"]
    effect    = "Allow"
    resources = var.assume_role
  }
}

//  If service is glue use following policy
resource "aws_iam_role_policy" "glue-policy" {
  count  = var.enabled && var.allow_service == "glue.amazonaws.com" ? 1 : 0
  name   = "glue-policy"
  policy = data.aws_iam_policy_document.glue-policy[0].json
  role   = aws_iam_role.role[0].id
}

data "aws_iam_policy_document" "glue-policy" {
  count = var.enabled && var.allow_service == "glue.amazonaws.com" ? 1 : 0

  statement {
    sid    = "GluePolicy"
    effect = "Allow"

    actions = [
      "glue:*",
      "cloudwatch:PutMetricData",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "GlueS3Bucket"
    effect = "Allow"

    actions = [
      "s3:CreateBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]

    resources = [
      "arn:aws:s3:::aws-glue-*",
      "arn:aws:s3:::crawler-public*",
    ]
  }

  statement {
    sid    = "GlueLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "arn:aws:logs:*:*:/aws-glue/*",
    ]
  }
}

//  If service is codepipeline use following policy
resource "aws_iam_role_policy" "codepipeline-policy" {
  count  = var.enabled && var.allow_service == "codepipeline.amazonaws.com" ? 1 : 0
  name   = "codepipeline-policy"
  policy = data.aws_iam_policy_document.codepipeline-policy[0].json
  role   = aws_iam_role.role[0].id
}

data "aws_iam_policy_document" "codepipeline-policy" {
  count = var.enabled && var.allow_service == "codepipeline.amazonaws.com" ? 1 : 0
  statement {
    sid = "PassRole"
    actions = [
      "iam:PassRole"
    ]
    resources = [
      "*"
    ]
    effect = "Allow"
    condition {
      test = "StringEqualsIfExists"
      values = [
        "cloudformation.amazonaws.com",
        "elasticbeanstalk.amazonaws.com",
        "ec2.amazonaws.com",
        "ecs-tasks.amazonaws.com"
      ]
      variable = "iam:PassedToService"
    }
  }
  statement {
    sid = "CodeCommit"
    actions = [
      "codecommit:CancelUploadArchive",
      "codecommit:GetBranch",
      "codecommit:GetCommit",
      "codecommit:GetUploadArchiveStatus",
      "codecommit:UploadArchive"
    ]
    effect = "Allow"
    resources = [
      "*"
    ]
  }
  statement {
    sid = "CodeDeploy"
    actions = [
      "codedeploy:CreateDeployment",
      "codedeploy:GetApplication",
      "codedeploy:GetApplicationRevision",
      "codedeploy:GetDeployment",
      "codedeploy:GetDeploymentConfig",
      "codedeploy:RegisterApplicationRevision"
    ]
    effect = "Allow"
    resources = [
      "*"
    ]
  }
  statement {
    sid = "Misc"
    actions = [
      "ecr:DescribeImages",
      "elasticbeanstalk:*",
      "ec2:*",
      "elasticloadbalancing:*",
      "autoscaling:*",
      "cloudwatch:*",
      "s3:*",
      "sns:*",
      "cloudformation:*",
      "rds:*",
      "sqs:*",
      "ecs:*"
    ]
    effect = "Allow"
    resources = [
      "*"
    ]
  }
  statement {
    sid = "Lambda"
    actions = [
      "lambda:InvokeFunction",
      "lambda:ListFunctions"
    ]
    effect = "Allow"
    resources = [
      "*"
    ]
  }
  statement {
    sid = "OpsWorks"
    actions = [
      "opsworks:CreateDeployment",
      "opsworks:DescribeApps",
      "opsworks:DescribeCommands",
      "opsworks:DescribeDeployments",
      "opsworks:DescribeInstances",
      "opsworks:DescribeStacks",
      "opsworks:UpdateApp",
      "opsworks:UpdateStack"
    ]
    effect = "Allow"
    resources = [
      "*"
    ]
  }
  statement {
    sid = "CloudFormation"
    actions = [
      "cloudformation:CreateStack",
      "cloudformation:DeleteStack",
      "cloudformation:DescribeStacks",
      "cloudformation:UpdateStack",
      "cloudformation:CreateChangeSet",
      "cloudformation:DeleteChangeSet",
      "cloudformation:DescribeChangeSet",
      "cloudformation:ExecuteChangeSet",
      "cloudformation:SetStackPolicy",
      "cloudformation:ValidateTemplate"
    ]
    effect = "Allow"
    resources = [
      "*"
    ]
  }
  statement {
    sid = "CodeBuild"
    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild"
    ]
    effect = "Allow"
    resources = [
      "*"
    ]
  }
  statement {
    sid = "DeviceFarm"
    actions = [
      "devicefarm:ListProjects",
      "devicefarm:ListDevicePools",
      "devicefarm:GetRun",
      "devicefarm:GetUpload",
      "devicefarm:CreateUpload",
      "devicefarm:ScheduleRun"
    ]
    effect = "Allow"
    resources = [
      "*"
    ]
  }
  statement {
    sid = "ServiceCatalog"
    actions = [
      "servicecatalog:ListProvisioningArtifacts",
      "servicecatalog:CreateProvisioningArtifact",
      "servicecatalog:DescribeProvisioningArtifact",
      "servicecatalog:DeleteProvisioningArtifact",
      "servicecatalog:UpdateProduct"
    ]
    effect = "Allow"
    resources = [
      "*"
    ]
  }
}

// Add KMS policy
resource "aws_iam_role_policy" "kms-policy" {
  count  = var.enabled && length(concat(var.s3_read, var.s3_write)) > 0 ? 1 : 0
  name   = "kms-policy"
  policy = data.aws_iam_policy_document.kms-policy.json
  role   = aws_iam_role.role[0].id
}

data "aws_iam_policy_document" "kms-policy" {
  statement {
    sid = "KMSAccess"

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]

    resources = [
      "arn:aws:kms:*:${data.aws_caller_identity.identity.account_id}:key/*",
    ]
  }
}

// Read/List access to specified S3 buckets
resource "aws_iam_role_policy" "s3-read-policy" {
  count = var.enabled && length(compact(var.s3_read)) > 0 ? length(compact(var.s3_read)) : 0
  name  = "s3-read-policy_${var.s3_read[count.index]}"

  policy = <<EOF
{
        "Version": "2012-10-17",
        "Statement": [{
                "Effect": "Allow",
                "Action": [
                  "s3:Get*",
                  "s3:List*"
                ],
                "Resource": [
                        "arn:aws:s3:::${var.s3_read[count.index]}",
                        "arn:aws:s3:::${var.s3_read[count.index]}/*"
                ]
        }]
}
EOF

  role = aws_iam_role.role[0].id
}

// Full access to specified S3 buckets
resource "aws_iam_role_policy" "s3-write-policy" {
  count = var.enabled && length(compact(var.s3_write)) > 0 ? length(compact(var.s3_write)) : 0
  name  = "s3-write-policy_${var.s3_write[count.index]}"

  policy = <<EOF
{
        "Version": "2012-10-17",
        "Statement": [{
                "Effect": "Allow",
                "Action": "s3:*",
                "Resource": [
                        "arn:aws:s3:::${var.s3_write[count.index]}",
                        "arn:aws:s3:::${var.s3_write[count.index]}/*"
                ]
        }]
}
EOF

  role = aws_iam_role.role[0].id
}

resource "aws_iam_role_policy" "main" {
  count = var.enabled && length(compact(var.dynamodb_tables)) > 0 ? length(compact(var.dynamodb_tables)) : 0
  name  = "dynamodb-policy_${var.dynamodb_tables[count.index]}"

  policy = <<EOF
{
        "Version": "2012-10-17",
        "Statement": [{
                "Effect": "Allow",
                "Action": "dynamodb:*",
                "Resource": "arn:aws:dynamodb:*:${data.aws_caller_identity.identity.account_id}:table/${var.dynamodb_tables[count.index]}"
        }]
}
EOF

  role = aws_iam_role.role[0].id
}

// Managed policy
resource "aws_iam_role_policy_attachment" "policy-managed" {
  count      = var.enabled && length(compact(var.policy_managed)) > 0 ? length(compact(var.policy_managed)) : 0
  policy_arn = "arn:aws:iam::aws:policy/${var.policy_managed[count.index]}"
  role       = aws_iam_role.role[0].id
}

// Custom policy inline
resource "aws_iam_role_policy" "policy-inline" {
  count  = var.enabled && var.policy_inline != "" ? 1 : 0
  name   = "policy-inline"
  role   = aws_iam_role.role[0].id
  policy = var.policy_inline
}

// Custom policy from file
// Perhaps it should be template to allow some paramenters (account_id?)
resource "aws_iam_role_policy" "policy-file" {
  count  = var.enabled && length(compact(var.policy_file)) > 0 ? length(compact(var.policy_file)) : 0
  name   = "policy-file_${basename(var.policy_file[count.index])}"
  role   = aws_iam_role.role[0].id
  policy = file(format("%s", var.policy_file[count.index]))
}
