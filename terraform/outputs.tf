output "cluster_name" {
  value       = module.eks.cluster_name
  description = "EKS cluster name"
}

output "cluster_endpoint" {
  value       = module.eks.cluster_endpoint
  description = "EKS API server endpoint"
}

output "region" {
  value       = var.aws_region
  description = "AWS region"
}

output "update_kubeconfig_command" {
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
  description = "Command to configure kubectl"
}

output "efs_file_system_id" {
  value       = aws_efs_file_system.this.id
  description = "EFS file system id (for RWX PVCs)"
}

output "mlflow_s3_bucket" {
  value       = aws_s3_bucket.mlflow.bucket
  description = "S3 bucket used for MLflow artifacts"
}

output "ingress_nginx_lb_dns" {
  value       = try(data.aws_lb.ingress_nginx[0].dns_name, null)
  description = "DNS name of the ingress-nginx LoadBalancer (null if not discoverable or DNS disabled)"
}

output "airflow_public_hostname" {
  value       = try(aws_route53_record.airflow[0].fqdn, null)
  description = "Public DNS name for Airflow (null if route53_zone_id not set or ingress LB not found)"
}

output "mlflow_public_hostname" {
  value       = try(aws_route53_record.mlflow[0].fqdn, null)
  description = "Public DNS name for MLflow (null if route53_zone_id not set or ingress LB not found)"
}

output "airflow_public_url" {
  value       = try("http://${aws_route53_record.airflow[0].fqdn}", null)
  description = "Convenience URL for Airflow (HTTP; add TLS later if desired)"
}

output "mlflow_public_url" {
  value       = try("http://${aws_route53_record.mlflow[0].fqdn}", null)
  description = "Convenience URL for MLflow (HTTP; add TLS later if desired)"
}
