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

2) Inicializa y aplica:
   - terraform init
   - terraform apply

3) Configura kubectl:
   - (ver output) aws eks update-kubeconfig --region <REGION> --name <CLUSTER_NAME>

Notas
-----
- Este stack instala el addon aws-ebs-csi-driver para PVCs basados en EBS.
- Ingress (nginx o ALB controller) se instala aparte (Helm), según tu elección.
