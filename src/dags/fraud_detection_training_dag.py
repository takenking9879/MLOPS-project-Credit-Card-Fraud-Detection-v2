from airflow.sdk import DAG
from airflow.providers.standard.operators.python import PythonOperator
from airflow.providers.standard.operators.bash import BashOperator
from airflow.exceptions import AirflowException
import logging
from datetime import datetime, timedelta
from fraud_detection_training import FraudDetectionTraining
import os
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
        trainer = FraudDetectionTraining() #Quitar el config si no es k8s
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
