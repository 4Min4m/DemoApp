output "web_url" {
  description = "URL of the web application"
  value       = "Web app deployed via Auto Scaling Group. Check EC2 instances with tag Environment=${var.environment} for Public IP."
  depends_on  = [module.ec2]
}