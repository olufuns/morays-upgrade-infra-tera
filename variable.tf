variable "aws_region" {
  type        = string
  description = "AWS region in which to create the infrastructure."
  default     = "eu-west-2"
}

variable "project_name" {
  type        = string
  description = "Short name used to identify this new project."
  default     = "morays-ha"
}

variable "environment" {
  type        = string
  description = "Environment name used in resource tags."
  default     = "dev"
}

variable "vpc_cidr" {
  type        = string
  description = "IPv4 range for the new project VPC."
  default     = "10.42.0.0/16"
}

variable "public_subnet_a_cidr" {
  type        = string
  description = "First public subnet CIDR."
  default     = "10.42.1.0/24"
}

variable "public_subnet_b_cidr" {
  type        = string
  description = "Second public subnet CIDR."
  default     = "10.42.2.0/24"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type. Two instances launch by default."
  default     = "t3.micro"
}

variable "key_name" {
  type        = string
  description = "Existing AWS EC2 key pair name (not the .pem path)."
  default     = "olu1"
}

variable "ssh_cidr" {
  type        = string
  description = "Your current public IPv4 address with /32 suffix; null disables SSH access."
  default     = null
  nullable    = true
}

variable "min_size" {
  type        = number
  description = "Minimum number of EC2 instances in Auto Scaling."
  default     = 2
}

variable "desired_capacity" {
  type        = number
  description = "Initial number of EC2 instances."
  default     = 2
}

variable "max_size" {
  type        = number
  description = "Maximum number of EC2 instances."
  default     = 4
}

variable "cpu_target_percent" {
  type        = number
  description = "Average CPU percentage targeted by Auto Scaling."
  default     = 60
}

variable "enable_elb_health_checks" {
  type        = bool
  description = "Set true after the first website release to replace EC2 instances that fail ALB health checks."
  default     = false
}