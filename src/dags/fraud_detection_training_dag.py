from airflow.sdk import DAG
from airflow.providers.standard.operators.python import PythonOperator
from airflow.providers.standard.operators.bash import BashOperator
from airflow.exceptions import AirflowException
import logging
from datetime import datetime, timedelta
from fraud_detection_training import FraudDetectionTraining
import os
import glob
import yaml
import re
logger = logging.getLogger(__name__)
default_args = {
    'owner': 'datamasterylab.com',
    'depends_on_past': False,
    'start_date': datetime(2025, 3, 3),
    'max_active_runs': 1,
}
# 'execution_timeout': timedelta(minutes=120),

def _train_model(**context):
    try:
        logger.info('Initializing fraud detection training')

        ##airflow k8s 
        current_dir = os.path.dirname(os.path.realpath(__file__))
        logger.info(f"Current directory: {current_dir}")

        # Buscar YAML en el mismo directorio
        yaml_files = glob.glob(os.path.join(current_dir, "*.yaml"))
        config_path = yaml_files[0]
        # Leer el YAML original como texto
        with open(config_path, "r") as f:
            content = f.read()
        # Reemplazo dinámico de variables de entorno (${VAR} -> os.environ)
        content = re.sub(r"\$\{(\w+)\}", lambda m: os.getenv(m.group(1), ""), content)
        # Crear nuevo YAML: config_k8s_secrets.yaml
        base_name = os.path.basename(config_path).replace(".yaml", "_secrets.yaml")
        new_config_path = os.path.join(current_dir, base_name)
        # Guardar el YAML con las secrets inyectadas
        with open(new_config_path, "w") as f:
            f.write(content)
        logger.info(f"Created secrets YAML: {new_config_path}")

        # Inicializar el trainer con el YAML generado
        trainer = FraudDetectionTraining(config_path=new_config_path) #eliminar config_path para la version de compose
        model, precision = trainer.train_model()

        return {'status': 'success', 'precision': precision}
    except Exception as e:
        logger.error('Training failed: %s', str(e), exc_info=True)
        raise AirflowException(f'Model training failed: {str(e)}')
    
with DAG(
    'fraud_detection_training',
    default_args=default_args,
    description='Fraud detection model training pipeline',
    schedule='0 3 * * *',
    catchup=False,
    tags=['fraud', 'ML']
) as dag:

    validate_environment = BashOperator(
        task_id='validate_environment',
        bash_command='''
        echo "Validating environment..."
        test -f /app/config.yaml &&
        test -f /app/.env &&
        echo "Environment is valid!" || echo "Skipping validation: config or .env missing"
        '''
    )

    training_task = PythonOperator(
        task_id='execute_training',
        python_callable=_train_model,
    )

    cleanup_task = BashOperator(
        task_id='cleanup_resources',
        bash_command='rm -f /app/temp/*.pkl || true',
        trigger_rule='all_done'
    )

    validate_environment >> training_task >> cleanup_task

    dag.doc_md = """
    ## Fraud Detection Training Pipeline

    Daily training of fraud detection model using:
    - Transaction data from Kafka
    - XGBoost classifier with precision optimisation
    - MLflow for experiment tracking
    """
