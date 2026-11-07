# Command document shared with the EC2 launch-time bootstrap script.
# State Manager targets each new tagged EC2 instance automatically and
# also reconciles website content every 30 minutes.
resource "aws_ssm_document" "morays_website" {
  name            = "${var.project_name}-${var.environment}-configure-website"
  document_type   = "Command"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Install Apache and deploy latest versioned Morays website from private S3"
    mainSteps = [{
      action = "aws:runShellScript"
      name   = "configureMoraysWebsite"
      inputs = {
        timeoutSeconds = "900"
        runCommand = [templatefile("${path.module}/scripts/configure_from_s3.sh.tftpl", {
          artifact_bucket = aws_s3_bucket.website_artifacts.bucket
          aws_region      = var.aws_region
        })]
      }
    }]
  })
}

resource "aws_ssm_association" "morays_website" {
  name             = aws_ssm_document.morays_website.name
  association_name = "${var.project_name}-${var.environment}-website-reconciliation"

  targets {
    key    = "tag:MoraysDeploy"
    values = ["${var.project_name}-${var.environment}-website"]
  }

  # A new, matching managed instance also runs this association when it appears.
  schedule_expression = "rate(30 minutes)"
  max_concurrency     = "1"
  max_errors          = "0"
  compliance_severity = "MEDIUM"
}
