# Auto Scaling distributes EC2 servers between both public subnets.
resource "aws_autoscaling_group" "morays_web" {
  name                = "${var.project_name}-${var.environment}-asg"
  min_size            = var.min_size
  desired_capacity    = var.desired_capacity
  max_size            = var.max_size
  vpc_zone_identifier = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  target_group_arns   = [aws_lb_target_group.morays_web.arn]

  # First apply: leave this false while there is no website artifact in S3.
  # After the first successful Ansible release, set enable_elb_health_checks=true
  # and apply again so ASG can replace web servers that fail ALB health checks.
  health_check_type         = var.enable_elb_health_checks ? "ELB" : "EC2"
  health_check_grace_period = 900

  # Ensure instance read permissions exist before launching the servers.
  depends_on = [aws_iam_role_policy.ec2_site_read]

  launch_template {
    id      = aws_launch_template.morays_web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-web-${var.environment}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "webserver"
    propagate_at_launch = true
  }

  # Dedicated tag avoids accidentally targeting other instances with SSM.
  tag {
    key                 = "MoraysDeploy"
    value               = "${var.project_name}-${var.environment}-website"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "${var.project_name}-${var.environment}-cpu-policy"
  autoscaling_group_name = aws_autoscaling_group.morays_web.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = var.cpu_target_percent
  }
}