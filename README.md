# AWS Terraform Demo

This is a lightweight AWS infrastructure demo showcasing Terraform, CI/CD, monitoring, Disaster Recovery, and optimization.

## Architecture
- **VPC**: Two public subnets in different AZs (us-east-1a, us-east-1b).
- **EC2**: Auto Scaling Group with Spot Instances running Nginx.
- **Auto Scaling Group**: Runs Nginx web servers across AZs.
- **S3**: Stores Terraform State and backups.
- **DynamoDB**: State locking.
- **CloudWatch**: Monitors CPU and triggers scaling.
- **Route 53**: Health Checks for High Availability.
- **SNS**: Sends email alerts
- **VPC Endpoint**: Reduces S3 latency.
- **IAM Role**: Prepares for AWS X-Ray.

## Application
- A simple HTML page (`app/index.html`) served by Nginx.
- Deployed to EC2 via S3 and updated through CI/CD.
- Version changes (e.g., `Version: 1.0` to `2.0`) are tested in the pipeline.

## CI/CD
- **Tool**: GitHub Actions.
- **Stages**: Init, Validate, Plan, Apply (manual approval for Prod).
- **Features**: Health Check, Slack notifications.
- **New Stages**:
  - `Check App File`: Ensures `index.html` exists.
  - `Test App Content`: Verifies the web page contains "Version" after deployment.

## Monitoring
- CloudWatch Alarms for CPU (>80%) and Auto Scaling (>70%).
- Nginx logs sent to CloudWatch Logs.

## Disaster Recovery
- **Multi-AZ**: Auto Scaling across two AZs.
- **Backups**: S3 for data backups.
- **Health Checks**: Route 53 monitors web server.

## Optimization
- **Compute**: Spot Instances and Auto Scaling Policy (CPU >70%).
- **Network**: VPC Endpoint for S3.
- **Cost**: Tags for Cost Explorer, Free Tier resources.

## Future Tools
- **AWS X-Ray**: IAM Role added for tracing (see `modules/ec2/main.tf`).
- **ArgoCD**: Sample GitOps config (see `manifests/argocd-app.yaml`).
- **Chaos Monkey**: Can test Auto Scaling resilience.

## Setup
1. Clone the repo: `git clone https://github.com/4Min4m/DemoApp`
2. Set AWS credentials in GitHub Secrets.
3. Create an S3 bucket (`my-terraform-state-demo`) and DynamoDB table (`terraform-locks`).
4. Run locally: `terraform init && terraform apply -var="environment=dev"`
5. GitHub Actions handles CI/CD.

## Scenarios
- **Auto Scaling**: Simulate high CPU with `stress` on an EC2 instance to trigger scaling.
- **High Availability/DR**: Terminate one EC2 instance; Auto Scaling replaces it in another AZ.