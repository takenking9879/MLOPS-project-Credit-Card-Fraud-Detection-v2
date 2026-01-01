Terraform EKS (VPC + EKS + Managed Node Group + EBS CSI)
========================================================

Requisitos
----------
- Terraform >= 1.5
- AWS CLI configurado (credenciales con permisos para crear VPC/EKS/IAM)

Uso rápido
----------
1) Edita valores:
   - Copia terraform.tfvars.example -> terraform.tfvars y ajusta.
    - Define `eks_admin_principals` con los IAM principal ARNs (roles/usuarios) que necesitan acceso admin al cluster.
       Esto crea Access Entries para que `kubectl/helm` (CI y local) no fallen con “the server has asked for the client to provide credentials”.
    - `github_actions_role_arn` queda como variable legacy (single principal) por compatibilidad.

2) Inicializa y aplica:
   - terraform init
   - terraform apply

3) Configura kubectl:
   - (ver output) aws eks update-kubeconfig --region <REGION> --name <CLUSTER_NAME>

Notas
-----
- Este stack instala el addon aws-ebs-csi-driver para PVCs basados en EBS.
- Ingress (nginx o ALB controller) se instala aparte (Helm), según tu elección.
