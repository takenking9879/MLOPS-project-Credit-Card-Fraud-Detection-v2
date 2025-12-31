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
  default     = 2
}

variable "node_min_size" {
  description = "Min nodes in the default node group"
  type        = number
  default     = 1
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
