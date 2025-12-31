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
