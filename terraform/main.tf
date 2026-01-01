data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  # S3 bucket names must be globally unique, lowercase, <= 63 chars, and contain only [a-z0-9-]
  mlflow_bucket_name_derived_raw = lower("mlflow-${data.aws_caller_identity.current.account_id}-${var.cluster_name}")
  mlflow_bucket_name_derived_sanitized = replace(
    replace(
      replace(local.mlflow_bucket_name_derived_raw, "/[^a-z0-9-]/", "-"),
      "/^-+/",
      ""
    ),
    "/-+$/",
    ""
  )
  mlflow_bucket_name = substr(
    (var.mlflow_bucket_name != "" ? var.mlflow_bucket_name : local.mlflow_bucket_name_derived_sanitized),
    0,
    63
  )

  eks_admin_principals = toset(compact(concat(
    var.eks_admin_principals,
    var.github_actions_role_arn != "" ? [var.github_actions_role_arn] : []
  )))
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.16.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i + 8)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = {
    Project = var.cluster_name
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.24.0"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # GitHub-hosted runners are outside the VPC; they can't reach a private-only endpoint.
  # Enable the public endpoint so CI can run kubectl/helm.
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  # NOTE: This is intentionally wide to avoid GitHub IP allowlist churn.
  # If you want to lock it down later, switch to a self-hosted runner in the VPC or set a fixed CIDR.
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

  # Use EKS Access Entries so the GitHub Actions role can authenticate to the cluster.
  authentication_mode = "API_AND_CONFIG_MAP"

  access_entries = {
    for principal_arn in local.eks_admin_principals :
    (
      principal_arn == var.github_actions_role_arn && var.github_actions_role_arn != "" ? "github_actions" :
      "admin-${replace(replace(principal_arn, ":", "-"), "/", "-")}"
      ) => {
      principal_arn = principal_arn

      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  enable_irsa = true

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      ami_type = "AL2023_x86_64_STANDARD"
    }
  }

  tags = {
    Project = var.cluster_name
  }
}

# =====================
# S3 (MLflow artifacts)
# =====================
resource "aws_s3_bucket" "mlflow" {
  bucket        = local.mlflow_bucket_name
  force_destroy = false

  tags = {
    Name    = local.mlflow_bucket_name
    Project = var.cluster_name
  }
}

resource "aws_s3_bucket_versioning" "mlflow" {
  bucket = aws_s3_bucket.mlflow.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "mlflow" {
  bucket = aws_s3_bucket.mlflow.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "mlflow" {
  bucket = aws_s3_bucket.mlflow.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "mlflow" {
  bucket = aws_s3_bucket.mlflow.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# =====================
# EFS (para PVC RWX)
# =====================
resource "aws_security_group" "efs" {
  name_prefix = "${var.cluster_name}-efs-"
  description = "EFS security group"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "NFS from VPC"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = var.cluster_name
  }
}

resource "aws_efs_file_system" "this" {
  creation_token = "${var.cluster_name}-efs"
  encrypted      = true

  tags = {
    Name    = "${var.cluster_name}-efs"
    Project = var.cluster_name
  }
}

resource "aws_efs_mount_target" "private" {
  # Subnet IDs are unknown until apply; use stable numeric keys so plan can proceed.
  for_each = { for i in range(length(local.azs)) : tostring(i) => module.vpc.private_subnets[i] }

  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs.id]
}

module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.52.0"

  role_name_prefix      = "${var.cluster_name}-ebs-csi-"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name = module.eks.cluster_name
  addon_name   = "aws-ebs-csi-driver"

  service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn

  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [module.eks]
}

module "efs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.52.0"

  role_name_prefix      = "${var.cluster_name}-efs-csi-"
  attach_efs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:efs-csi-controller-sa"]
    }
  }
}

resource "aws_eks_addon" "efs_csi" {
  cluster_name = module.eks.cluster_name
  addon_name   = "aws-efs-csi-driver"

  service_account_role_arn = module.efs_csi_irsa_role.iam_role_arn

  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [module.eks]
}
