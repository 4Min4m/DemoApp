output "web_url" {
  value = "http://${module.ec2.asg_name}"
}