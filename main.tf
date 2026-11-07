# Fetch a recent Amazon Linux 2023 x86_64 AMI automatically.
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# A Launch Template is the blueprint for every new EC2 instance.
# Startup retrieves the latest Ansible-published website from private S3.
# The website itself stays in the separate Ansible project.
resource "aws_launch_template" "morays_web" {
  name_prefix            = "${var.project_name}-${var.environment}-"
  image_id               = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  update_default_version = true

  # New Auto Scaling instances configure themselves, even if Ansible is offline.
  # The same script is reused by Systems Manager State Manager.
  user_data = base64encode(templatefile("${path.module}/scripts/configure_from_s3.sh.tftpl", {
    artifact_bucket = aws_s3_bucket.website_artifacts.bucket
    aws_region      = var.aws_region
  }))

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  network_interfaces {
    device_index                = 0
    associate_public_ip_address = true
    security_groups             = [aws_security_group.web_sg.id]
    delete_on_termination       = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name         = "${var.project_name}-web-${var.environment}"
      Project      = var.project_name
      Environment  = var.environment
      Role         = "webserver"
      ManagedBy    = "Terraform"
      MoraysDeploy = "${var.project_name}-${var.environment}-website"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name    = "${var.project_name}-web-volume-${var.environment}"
      Project = var.project_name
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
