output "asg_name" {
  value = aws_autoscaling_group.web.name
}

output "instance_role_arn" {
  value = aws_iam_role.ec2_role.arn
}