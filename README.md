<div align="center">

# 🛡️ MLOPS-project-Credit-Card-Fraud-Detection-v2

[![Python](https://img.shields.io/badge/Python-3.11-blue?logo=python)](https://www.python.org/)  
[![Airflow](https://img.shields.io/badge/Airflow-3.x-yellow?logo=apache-airflow)](https://airflow.apache.org/)  
[![Spark](https://img.shields.io/badge/Spark-4.0.1-orange?logo=apache-spark)](https://spark.apache.org/)  
[![MLflow](https://img.shields.io/badge/MLflow-3.x-lightgrey?logo=mlflow)](https://mlflow.org/)  
[![Kafka](https://img.shields.io/badge/Kafka-3.6.1-ff6600?logo=apache-kafka)](https://kafka.apache.org/)  
[![Docker](https://img.shields.io/badge/Docker-24.0-blue?logo=docker)](https://www.docker.com/)  
[![MinIO](https://img.shields.io/badge/MinIO-RE/OS-00a2ff?logo=minio)](https://min.io/)  
[![Postgres](https://img.shields.io/badge/Postgres-15.0-336791?logo=postgresql)](https://www.postgresql.org/)  
[![Redis](https://img.shields.io/badge/Redis-7.x-cc0000?logo=redis)](https://redis.io/)

---

</div>

## 📋 Descripción general

**Autor:** Jorge Ángel Manzanares Cortés  
**Proyecto:** Build a Fraud Detection AI from Scratch — adaptación y modernización de un tutorial de CodeWithYu.  
**Origen / Tutorial base:** https://www.youtube.com/watch?v=BY26sqZLi3k

Resumen: este repositorio contiene mi versión actualizada y compatible con stacks modernos (Airflow 3.x, Spark 4.0.1, MLflow 3.x, Kafka ajustado a 3.6.1). El objetivo es un pipeline E2E reproducible que genera datos sintéticos de transacciones, los inyecta en Kafka, orquesta pipelines con Airflow para entrenamiento y registro en MLflow (artefactos en MinIO), y finalmente realiza inferencia en streaming con Spark, publicando alertas de fraude de vuelta a Kafka.

---

## 📌 Cambios principales realizados (migración y compatibilidad)

- **Airflow → 3.x**
  - El frontend y la organización interna de clases/funciones cambió. Actualicé DAGs, operadores y hooks a las nuevas rutas y APIs.
  - Ajustes en configuraciones de autenticación y en la inicialización del metastore.
- **Spark → 4.0.1**
  - Spark 4 requiere compatibilizaciones con ciertos conectores; **no** es compatible con Kafka-clients 4.x, por lo que opté por **kafka-clients 3.6.1** y adapté dependencias.
- **MLflow → 3.x**
  - Nueva capa de permisos/seguridad. Fue necesario crear una nueva `env` (variables/roles) y adaptar la configuración del servidor MLflow para aceptar hosts y credenciales correctamente.
- **Seguridad en configs**
  - Eliminé variables secretas del `config.yaml` y moví credenciales sensibles a `.env` o a secretos del orquestador (Docker secrets / Vault recomendado).

---

## 🧩 Contenedores (descripción funcional)

Lista de contenedores orquestados (ej. `docker-compose`):

- `src-inference-1`: Conector de inferencia (Spark structured streaming + UDFs para predicción en tiempo real).  
- `src-airflow-worker-1`, `src-airflow-worker-2`: Workers de ejecución (Celery / CeleryExecutor).  
- `src-flower-1`: Flower — monitor de tareas Celery.  
- `src-airflow-triggerer-1`: Triggerer de Airflow (tareas diferidas).  
- `src-airflow-scheduler-1`: Scheduler de Airflow.  
- `src-airflow-apiserver-1`: API server de Airflow.  
- `src-airflow-dag-processor-1`: Procesador de DAGs.  
- `mlflow-server`: Servidor MLflow (tracking, registry), con artefact store apuntando a MinIO.  
- `src-airflow-init-1`: Inicialización de DB y recursos de Airflow.  
- `mc`: MinIO Client (CLI) para gestionar buckets/artefactos.  
- `src-postgres-1`: PostgreSQL (backend/metastore).  
- `src-redis-1`: Redis (broker para Celery / caché).  
- `src-producer-1`, `src-producer-2`: Producers que generan transacciones sintéticas y las publican a Kafka.  
- `minio`: Servidor de objetos (artefactos de MLflow, datos, modelos).

---

## 🧾 Flujo de datos (alto nivel)

1. **Producers** generan transacciones sintéticas → publican a **Kafka** (topic: `transactions`).  
2. **Airflow** orquesta DAGs que consumen desde Kafka / ETL / entrenamiento: prepara datasets, ejecuta aprendizaje, registra runs y modelos en **MLflow**; artefactos y modelos almacenados en **MinIO**.  
3. **Inference container** (Spark streaming) lee topic `transactions`, procesa y calcula predicciones en tiempo real, y publica eventos de alerta a `fraud_predictions` (otro topic en Kafka).  
4. Monitoreo: Flower (tareas), logs centralizados y MLflow/LangSmith (o similar) para trazabilidad de experiments.

---

## 🔬 Generación de transacciones sintéticas (resumen de la lógica)

Las transacciones se generan con reglas estocásticas para simular patrones reales y fraude:

- Campos por transacción: `transaction_id`, `user_id`, `amount`, `currency`, `merchant`, `timestamp`, `location`, `is_fraud`.
- **Tipos de fraude simulados (reglas heurísticas):**
  - **Account takeover:** usuarios comprometidos (`compromised_users`) con transacciones grandes (>500) tienen probabilidad de fraude; monto y merchant se alteran.  
  - **Card testing:** múltiples micropagos pequeños (<2.0 USD) con patrón rápido; probabilidad condicionada al `user_id`.  
  - **Merchant collusion:** merchants de alto riesgo (`high_risk_merchants`) que realizan transacciones sospechosas por montos altos.  
  - **Anomalías geográficas:** transacciones desde países atípicos para el usuario (`CN`, `RU`, `GB`) en ocasiones específicas.  
  - **Fraude aleatorio de base:** tasa baja de fraude “baseline” para ruido realista (≈0.1–0.3%).  
- **Control de tasa:** se aplica una lógica adicional para mantener la tasa final de fraude entre ~1–2%.  
- **Validación:** cada transacción pasa por una validación de esquema antes de ser publicada.

> Nota: la generación está pensada para crear un balance realista entre transacciones legítimas y fraudulentas para entrenar y evaluar modelos.

---

## ✅ Esquema de eventos (requisitos y validaciones)

En vez de código, aquí tienes el **esquema resumido** (campo → tipo → restricciones):

- `transaction_id` → string, identificador único (UUID).  
- `user_id` → entero, rango típico 1000–9999 (o ID consistente).  
- `amount` → número decimal, mínimo 0.01, máximo ~10000.  
- `currency` → string, ISO-3 (ej. `USD`).  
- `merchant` → string.  
- `timestamp` → datetime ISO 8601 (UTC preferible).  
- `location` → string, ISO-2 país (ej. `US`, `MX`).  
- `is_fraud` → entero binario (0 o 1).  

Campos obligatorios para publicación: `transaction_id`, `user_id`, `amount`, `currency`, `timestamp`, `is_fraud`. El resto puede ser opcional pero recomendado.

---

## 🧠 Feature engineering y entrenamiento (resumen metodológico)

- **Feature engineering (batch):**
  - Variables temporales: hora del día, día del mes, indicador noche/fin de semana.  
  - Ratios y agregados históricos (rolling averages, tiempo desde última transacción) — cuando hay historial.  
  - Flags de merchant de alto riesgo, relaciones `amount / rolling_avg`.  
- **Pipeline ML (sklearn-style):**
  - Preprocesado de numéricas y categóricas (imputación, encoding).  
  - Rebalanceo con **SMOTE** para mitigar el desbalance de clases.  
  - Búsqueda de hiperparámetros con **RandomizedSearchCV** (o RandomGridSearchCV en tu implementación).  
  - Modelo final: clasificadores tradicionales (ej. RandomForest / XGBoost — según experimentos).  
- **Resultados reportados (tus runs):**
  - **Precisión (precision):** 0.88  
  - **Recall:** 0.40  
  - Métrica de decisión: se priorizó **precision** para minimizar falsos positivos en ambiente de producción; recall se ajusta en inferencia vía umbral.

---

## 🚀 Inferencia en streaming (arquitectura y decisiones)

- **Motor:** Spark Structured Streaming (Spark 4.0.1).  
- **Lectura:** `readStream` desde Kafka (`transactions`), `startingOffsets=latest`.  
- **Parsing:** JSON → esquema estructurado (tipos definidos para cada campo).  
- **Feature enrichment:** crear columnas temporales, indicadores (is_night, is_weekend), ratios y flags de riesgo.  
- **Modelo en producción:** modelo entrenado serializado (joblib) cargado por el proceso de Spark y **broadcasted** (para evitar re-envío en cada task).  
- **Predicción:** UDF vectorizada (Pandas UDF) que recibe batches y retorna predicción binaria.  
  - Umbral de clasificación sugerido: **0.70** (ajustable según trade-off precision/recall).  
- **Salida:** solo predicciones de fraude de alta confianza se publican a `fraud_predictions` (Kafka), con checkpointing (por ejemplo `checkpoints/checkpoint`) para tolerancia a fallos.  
- **Observabilidad:** logs estructurados (INFO/ERROR) y monitoreo de latencia en el pipeline.

---

## 🔧 Problemas encontrados y soluciones (resumen práctico)

- **MLflow: Rechazo por encabezado Host / seguridad**
  - Causa: nueva política de validación de Host y seguridad en MLflow 3.x.  
  - Solución: crear una nueva env / variable `MLFLOW_SERVER_ALLOWED_HOSTS` adecuada y corregir la configuración del server (host/puerto) y reverse-proxy si aplica.
- **Airflow: rutas y frontend**
  - Causa: reestructuración de módulos y cambios en frontend.  
  - Solución: actualizar imports, operadores y adaptadores; revisar breaking changes de Airflow 3.x.
- **Spark — compatibilidad con Kafka-client**
  - Problema: Spark 4.0.1 no compatible con kafka-clients 4.x en mi stack.  
  - Solución: usar **kafka-clients 3.6.1**, fijar versiones de jars y adaptar `spark.jars.packages` y dependencias.
- **Seguridad de configuración**
  - Problema: secretos en `config.yaml`.  
  - Solución: remover secretos del `config.yaml`, usar `.env`, Docker secrets o un secret manager.
- **Validación de esquema**
  - Implementar validación preventiva para evitar mensajes malformados en Kafka.

---

## 📦 Reproducción (guía rápida, sin comandos)

1. Preparar `.env` con variables sensibles (KAFKA creds, MLflow credentials, MinIO keys).  
2. Levantar infra: Postgres, Redis, MinIO, Kafka, Zookeeper (si aplica), MLflow, Airflow via containers.  
3. Inicializar metastore de Airflow (migraciones) y crear buckets en MinIO.  
4. Ejecutar producers para empezar a enviar transacciones a Kafka.  
5. Ejecutar DAGs de Airflow para ETL / entrenamiento. Ver runs en MLflow.  
6. Levantar container de inferencia (Spark) para leer stream y generar `fraud_predictions`.

> Nota: Ajustes de red / hosts / puertos y configuración de SASL/SCRAM o SSL en Kafka son críticos — revisa variables en `.env` y `config.yaml`.

---

## 📈 Monitoring & MLOps

- **Tracking:** MLflow Tracking + Registry para versiones de modelo.  
- **Artefactos:** MinIO como object store para artefactos y modelos.  
- **Orquestación:** Airflow 3.x para pipelines programados y DAGs de entrenamiento.  
- **Observabilidad:** Flower para Celery; logs estructurados; sugerido: Prometheus + Grafana para métricas de latencia y errores.  
- **Trazabilidad:** incluir run-id de MLflow en metadatos de inferencia para correlación.

---

## 🛠️ Recomendaciones y siguientes pasos

- Añadir tests end-to-end (simulación de producers → Kafka → Airflow → MLflow → Inference) en CI.  
- Implementar retraining automático (drift detection) traducido en DAGs de Airflow.  
- Mejorar el recall del modelo explorando ensembles y features agregadas históricamente (ventanas temporales).  
- Habilitar métricas de modelo en producción (drift, AUC over time, tasa de falsos positivos por segmento).
- **PASO SIGUIENTE: Implementar un pipeline CI/CD usando EKS y Kubernetes**

---

## 🧾 Documentación & archivos importantes (qué revisar)

- `docker-compose.yml` / orquestador: definición de servicios y redes.  
- `config.yaml` (sin secretos): plantillas de configuración.  
- `.env.example`: variables necesarias para levantar el entorno.  
- `dags/`: DAGs de Airflow (ETL / train / register).  
- `models/` / `artifacts/`: lugar donde MLflow persiste los modelos (referenciados a MinIO).  
- `producers/` y `inference/`: scripts de generación y de inferencia (Spark).

---

## 📘 Créditos y licencia

Basado en el tutorial de CodeWithYu (video referenciado arriba). Esta versión contiene **mis adaptaciones y mejoras** para compatibilidad con versiones modernas de las herramientas y cambios en seguridad/infraestructura.

---

## 🧑‍💻 Autor & repositorio

**Jorge Ángel Manzanares Cortés**  
Repositorio: `MLOPS-project-Credit-Card-Fraud-Detection-v2`  
🌐 GitHub: https://github.com/takenking9879

---
