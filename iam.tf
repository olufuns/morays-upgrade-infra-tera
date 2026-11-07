# Permit secure Systems Manager access as an alternative to opening SSH.
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_ssm" {
  name               = "${var.project_name}-${var.environment}-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-${var.environment}-profile"
  role = aws_iam_role.ec2_ssm.name
}


# Read-only access to the exact artifacts needed by the web servers.
# Publishing to S3 remains a privilege of the local AWS CLI identity,
# NOT of the EC2 instances themselves.
data "aws_iam_policy_document" "ec2_site_read" {
  statement {
    sid     = "ReadPublishedSiteObjects"
    effect  = "Allow"
    actions = ["s3:GetObject"]
    resources = [
      "${aws_s3_bucket.website_artifacts.arn}/current.txt",
      "${aws_s3_bucket.website_artifacts.arn}/releases/*"
    ]
  }

  statement {
    sid       = "ListOnlyReleasePrefixes"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.website_artifacts.arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["releases/*"]
    }
  }
}

resource "aws_iam_role_policy" "ec2_site_read" {
  name   = "${var.project_name}-${var.environment}-site-read"
  role   = aws_iam_role.ec2_ssm.id
  policy = data.aws_iam_policy_document.ec2_site_read.json
}