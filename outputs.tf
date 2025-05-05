output "web_url" {
  description = "URL of the web application (Dev environment)"
  value       = "Web app deployed via Auto Scaling Group. Check EC2 instances with tag Environment=dev for Public IP."
  depends_on  = [module.ec2]
}