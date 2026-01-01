variable "aws_region" {
  description = "AWS region where EKS will be created"
  type        = string
  default     = "us-east-2"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "mlops-fraud-eks"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.32"
}

variable "vpc_cidr" {
  description = "CIDR for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "node_instance_types" {
  description = "Instance types for the managed node group"
  type        = list(string)
  default     = ["m7i-flex.large"]
}

variable "node_desired_size" {
  description = "Desired nodes in the default node group"
  type        = number
  default     = 3
}

variable "node_min_size" {
  description = "Min nodes in the default node group"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Max nodes in the default node group"
  type        = number
  default     = 4
}

variable "mlflow_bucket_name" {
  description = "Optional explicit S3 bucket name for MLflow artifacts. If empty, a globally-unique name is derived from account id + cluster name."
  type        = string
  default     = ""
}

variable "eks_admin_principals" {
  description = "IAM principal ARNs (users/roles) to grant EKS cluster-admin via EKS Access Entries. Useful for local kubectl access and CI roles."
  type        = list(string)
  default     = ["arn:aws:iam::797926359381:user/prod-deployment-user"]
}

variable "github_actions_role_arn" {
  description = "Optional legacy single principal ARN (typically the GitHub Actions role). Prefer eks_admin_principals."
  type        = string
  default     = "arn:aws:iam::797926359381:role/eks-terraform-cicd"
}

variable "route53_zone_id" {
  description = "Optional Route53 hosted zone id where public DNS records will be created for Airflow/MLflow. Leave empty to disable DNS management."
  type        = string
  default     = ""
}

variable "airflow_subdomain" {
  description = "Subdomain label to create for Airflow (record name will be <subdomain>.<zone>)."
  type        = string
  default     = "airflow"
}

variable "mlflow_subdomain" {
  description = "Subdomain label to create for MLflow (record name will be <subdomain>.<zone>)."
  type        = string
  default     = "mlflow"
}
