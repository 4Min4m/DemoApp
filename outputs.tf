output "web_url" {
  description = "URL of the web application (Dev environment)"
  value       = "http://${aws_instance.web.public_ip}"
  depends_on  = [module.ec2]
}