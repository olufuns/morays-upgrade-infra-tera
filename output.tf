output "aws_region" {
  description = "Region used by the project."
  value       = var.aws_region
}

output "vpc_id" {
  description = "New VPC ID."
  value       = aws_vpc.morays_vpc.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs in two separate AZs."
  value       = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

output "availability_zones" {
  description = "Zones selected for the public subnets."
  value       = [aws_subnet.public_a.availability_zone, aws_subnet.public_b.availability_zone]
}

output "alb_dns_name" {
  description = "AWS hostname for the load balancer."
  value       = aws_lb.morays_alb.dns_name
}

output "website_url" {
  description = "The website URL. It will not work until Ansible installs the web application."
  value       = "http://${aws_lb.morays_alb.dns_name}"
}

output "target_group_arn" {
  description = "Target group ARN for checking instance health."
  value       = aws_lb_target_group.morays_web.arn
}

output "autoscaling_group_name" {
  description = "ASG name for monitoring and future Ansible targeting."
  value       = aws_autoscaling_group.morays_web.name
}

output "web_security_group_id" {
  description = "EC2 security group (SSH limited to ssh_cidr if configured)."
  value       = aws_security_group.web_sg.id
}

output "site_artifact_bucket" {
  description = "Private S3 bucket into which Ansible publishes versioned website releases."
  value       = aws_s3_bucket.website_artifacts.bucket
}

output "ssm_association_id" {
  description = "Systems Manager State Manager association for automatic deployment and drift repair."
  value       = aws_ssm_association.morays_website.association_id
}

output "website_release_pointer" {
  description = "S3 location of the currently active website release pointer."
  value       = "s3://${aws_s3_bucket.website_artifacts.bucket}/current.txt"
}
