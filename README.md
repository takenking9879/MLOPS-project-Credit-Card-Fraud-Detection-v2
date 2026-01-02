<!--
Tip: este README está pensado para verse bien en GitHub.
Si quieres mostrar el diagrama, exporta `architecture/architecture.drawio` a PNG/SVG.
-->

# 🛡️ MLOPS-project-Credit-Card-Fraud-Detection-v2

<p align="center">
  <img src="https://img.shields.io/badge/Python-3.11-blue?logo=python" />
  <img src="https://img.shields.io/badge/Airflow-3.x-yellow?logo=apache-airflow" />
  <img src="https://img.shields.io/badge/Spark-4.0.1-orange?logo=apache-spark" />
  <img src="https://img.shields.io/badge/MLflow-3.x-lightgrey?logo=mlflow" />
  <img src="https://img.shields.io/badge/Kafka-3.6.1-ff6600?logo=apache-kafka" />
  <img src="https://img.shields.io/badge/Docker-24.x-blue?logo=docker" />
  <img src="https://img.shields.io/badge/Kubernetes-1.x-326CE5?logo=kubernetes" />
  <img src="https://img.shields.io/badge/Helm-3.x-0F1689?logo=helm" />
  <img src="https://img.shields.io/badge/Terraform-1.x-7B42BC?logo=terraform" />
  <img src="https://img.shields.io/badge/AWS-EKS-FF9900?logo=amazonaws" />
  <img src="https://img.shields.io/badge/AWS-S3-FF9900?logo=amazons3" />
  <img src="https://img.shields.io/badge/AWS-EFS-FF9900?logo=amazonaws" />
  <img src="https://img.shields.io/badge/AWS-IAM-FF9900?logo=amazonaws" />
</p>

Proyecto **end-to-end MLOps** para detección de fraude en transacciones con tarjetas de crédito:

- Generación de eventos (transacciones sintéticas)
- Entrenamiento orquestado con **Airflow**
- Tracking/Registry con **MLflow** (artefactos en storage tipo S3)
- **Inferencia en streaming** con **Spark Structured Streaming** consumiendo Kafka y publicando alertas

Incluye dos caminos de ejecución:

- **Local (Docker Compose)**: stack completo con MinIO (S3 compatible), Postgres, Redis, Airflow, MLflow y servicios.
- **Cloud (AWS/EKS)**: infraestructura con Terraform + despliegue de apps vía Helm/manifests.

> Este repo es mi adaptación y modernización del tutorial base de CodeWithYu: https://www.youtube.com/watch?v=BY26sqZLi3k

---

## 📋 Descripción general

**Autor:** Jorge Ángel Manzanares Cortés  
**Proyecto base:** Build a Fraud Detection AI from Scratch (CodeWithYu)  

Objetivo: tener un pipeline reproducible E2E que simule transacciones, entrene un modelo con trazabilidad completa (experiments + modelos + artefactos) y ejecute inferencia en streaming para generar eventos de fraude en tiempo real.

## Arquitectura (alto nivel)

- Flujo: **Producers → Kafka (`transactions`) → Airflow (training) → MLflow (runs/modelos) → Inference (Spark streaming) → Kafka (`fraud_predictions`)**
- Diagrama editable: `architecture/architecture.drawio`

---

## ☁️ Infraestructura en AWS (Terraform)

La infraestructura principal vive en `terraform/` y crea (o prepara) lo siguiente:

- **Networking:** VPC con subnets públicas/privadas + NAT (módulo `terraform-aws-vpc`).
- **Compute:** EKS + **Managed Node Group** (módulo `terraform-aws-eks`).
- **Storage (artefactos):** bucket **S3** para artefactos de MLflow (versioning + encryption + public access block).
- **Storage (RWX PVCs):** **EFS** cifrado + mount targets en subnets privadas.
- **Add-ons:** `aws-ebs-csi-driver` y `aws-efs-csi-driver` con **IRSA**.
- **Ingress:** `ingress-nginx` crea un **AWS LoadBalancer** en subnets públicas (se instala por Helm, pero el LB es AWS).
- **DNS (opcional):** `Route53` puede crear A-records `airflow.<zone>` y `mlflow.<zone>` apuntando al LB de ingress-nginx.
- **Acceso al cluster:** EKS **Access Entries** para roles/usuarios (útil para GitHub Actions y acceso local).

Archivos clave:

- `terraform/main.tf` (VPC, EKS, S3, EFS, add-ons)
- `terraform/dns.tf` (Route53 opcional)
- `terraform/outputs.tf` (URLs/DNS, bucket de artefactos, comando `update-kubeconfig`)

---

## 📌 Cambios principales (migración y compatibilidad)

- **Airflow → 3.x**: actualización de DAGs/operadores y cambios de API/estructura.
- **Spark → 4.0.1**: fijado de compatibilidades con conectores; el stack usa **Kafka clients 3.6.1**.
- **MLflow → 3.x**: ajustes por cambios de seguridad/host validation y configuración de tracking/artifacts.
- **Seguridad en configs**: secretos fuera de `config.yaml`, movidos a `src/.env` y a Kubernetes Secrets.

## Stack y prácticas

- **Orquestación:** Apache Airflow 3.x (DAGs de entrenamiento)
- **Streaming:** Apache Spark 4.0.1 + Structured Streaming
- **Mensajería:** Kafka 3.6.1 (topics `transactions` y `fraud_predictions`)
- **Experiment tracking / Model Registry:** MLflow 3.x
- **Persistencia:** PostgreSQL (metastore/backends) y almacenamiento de artefactos tipo S3 (MinIO en local/K8s o S3 en AWS)
- **Infra/Deploy:** Docker Compose (local) + Helm/Kubernetes (cluster) + Terraform (infra AWS/EKS)

---

## 🔬 Datos: generación de transacciones sintéticas

Las transacciones se generan con reglas estocásticas para simular patrones reales y fraude (útil para entrenar y probar el pipeline sin datos sensibles).

Ejemplos de patrones simulados:

- **Account takeover:** montos grandes y merchants inusuales.
- **Card testing:** micropagos repetitivos en poco tiempo.
- **Merchant collusion:** merchants de “alto riesgo” con tickets altos.
- **Anomalías geográficas:** ubicaciones atípicas para el usuario.
- **Fraude baseline:** ruido de baja probabilidad para realismo.

## Estructura del repo

- `src/`: entorno local con `docker-compose.yaml`, servicios y scripts
  - `src/airflow/`: imagen y dependencias de Airflow
  - `src/producer/`: producer de transacciones (dockerizable)
  - `src/inference/`: servicio de inferencia en streaming
- `k8s/`: despliegue en Kubernetes (Helm values/manifests)
  - `k8s/airflow/`, `k8s/mlflow/`, `k8s/postgres/`, `k8s/minio/`, `k8s/inference/`, `k8s/ingress-rules/`
- `architecture/`: diagramas (draw.io)

---

## Configuración

- Variables sensibles van en `src/.env` (y en cluster como Secret `env-secret`).
- Config de aplicación en `src/config.yaml` (por ejemplo MLflow/Kafka/Spark).

---

## Cómo correr en local (Docker Compose)

1) Dar permisos a scripts (una vez):
```bash
chmod +x init-multiple-dbs.sh wait-for-it.sh
```

2) Construir imagen de Airflow (solo una vez por cambios de dependencias):
```bash
docker compose --profile build build airflow-image
```

3) Levantar el stack (Airflow + servicios):
```bash
docker compose --profile flower up -d
```

4) Levantar inferencia (opcional):
```bash
docker compose up inference -d --build
```

Para apagar:
```bash
docker compose --profile flower down
```

---

## Deploy en Kubernetes (EKS / cluster)

Los manifests/values están en `k8s/` y el “runbook” base está en `k8s-steps.txt`.

Resumen (namespaces + Helm):

```bash
kubectl create namespace mlops-fraud

# Secret con variables (desde src/.env)
kubectl create secret generic env-secret --from-env-file=src/.env -n mlops-fraud

# Airflow (incluye PVC para modelos)
kubectl apply -f k8s/airflow/models-pvc.yaml -n mlops-fraud
helm install my-airflow apache-airflow/airflow --namespace mlops-fraud -f k8s/airflow/airflow_values.yaml

# PostgreSQL + MLflow
helm install postgres bitnami/postgresql -n mlops-fraud -f k8s/postgres/postgres_values.yaml
helm install my-mlflow community-charts/mlflow -n mlops-fraud -f k8s/mlflow/mlflow_values.yaml

# Ingress
helm upgrade --install ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace
helm install ingress-rule ./k8s/ingress-rules -n mlops-fraud

# MinIO (si usas object-store tipo S3 dentro del cluster)
helm install my-minio oci://registry-1.docker.io/cloudpirates/minio --version 0.5.6 \
  -f k8s/minio/minio_values.yaml -n mlops-fraud
```

> Nota: si apuntas a **AWS S3** como artifact store, normalmente no necesitas MinIO (y es importante no setear endpoints vacíos).

---

## CI/CD e Infra (Terraform)

- Infra en AWS/EKS con Terraform (carpeta `terraform/`).
- Charts/values para apps en `k8s/`.
- Pipelines con GitHub Actions (carpeta `.github/workflows/`), pensados para automatizar build/push/deploy.

---

## Credits

Basado en el tutorial de CodeWithYu (link arriba). Esta versión contiene mis adaptaciones para compatibilidad con **Airflow 3.x**, **Spark 4.0.1**, **MLflow 3.x** y el despliegue local + Kubernetes.

---

## Autor

**Jorge Ángel Manzanares Cortés**
