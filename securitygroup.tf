# The load balancer receives public HTTP traffic.
resource "aws_security_group" "alb_sg" {
  name_prefix = "${var.project_name}-alb-"
  description = "Allow public HTTP requests to the Application Load Balancer"
  vpc_id      = aws_vpc.morays_vpc.id

  tags = {
    Name = "${var.project_name}-alb-sg-${var.environment}"
  }
}

# The web servers accept HTTP requests only from our load balancer.
resource "aws_security_group" "web_sg" {
  name_prefix = "${var.project_name}-web-"
  description = "Allow HTTP from the ALB and optional administrator SSH"
  vpc_id      = aws_vpc.morays_vpc.id

  tags = {
    Name = "${var.project_name}-web-sg-${var.environment}"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb_sg.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Public HTTP to the load balancer"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_web" {
  security_group_id            = aws_security_group.alb_sg.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.web_sg.id
  description                  = "HTTP from load balancer to web instances"
}

resource "aws_vpc_security_group_ingress_rule" "web_http_from_alb" {
  security_group_id            = aws_security_group.web_sg.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.alb_sg.id
  description                  = "Accept HTTP only from the load balancer"
}

# Set ssh_cidr to your own public IPv4/32 in terraform.tfvars to enable SSH.
# SSH is disabled if ssh_cidr is null.
resource "aws_vpc_security_group_ingress_rule" "web_ssh_admin" {
  count             = var.ssh_cidr == null ? 0 : 1
  security_group_id = aws_security_group.web_sg.id
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.ssh_cidr
  description       = "SSH only from my current public IP"
}

resource "aws_vpc_security_group_egress_rule" "web_outbound" {
  security_group_id = aws_security_group.web_sg.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow instances to download updates and packages"
}