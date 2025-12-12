from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime, timedelta
import sys
import os

default_args = {
    'owner': 'data-engineer',
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

def list_and_process_files():
    # Imports pesados dentro da função para evitar timeout no DagBag
    import boto3
    sys.path.append(os.path.join(os.path.dirname(__file__), 'scripts'))
    from ingestion_brain import process_file
    
    s3 = boto3.client(
        's3',
        endpoint_url='http://minio:9000',
        aws_access_key_id='admin',
        aws_secret_access_key='password123'
    )
    
    # Listar ficheiros no Bronze
    response = s3.list_objects_v2(Bucket='lake-bronze')
    
    if 'Contents' not in response:
        print("Nenhum ficheiro encontrado.")
        return

    for obj in response['Contents']:
        file_key = obj['Key']
        # Processamento simples: processa tudo o que encontrar
        # (Num cenário real, verificaríamos se já foi processado antes)
        try:
            process_file('lake-bronze', file_key)
            print(f"Ficheiro {file_key} processado com sucesso.")
        except Exception as e:
            print(f"Erro ao processar {file_key}: {str(e)}")

with DAG(
    '1_ingestao_nao_estruturada',
    default_args=default_args,
    description='Pipeline de OCR e Transcrição',
    schedule_interval='*/30 * * * *', # Corre a cada 30 min
    start_date=datetime(2023, 1, 1),
    catchup=False,
) as dag:

    ingest_task = PythonOperator(
        task_id='process_bronze_files',
        python_callable=list_and_process_files,
    )
