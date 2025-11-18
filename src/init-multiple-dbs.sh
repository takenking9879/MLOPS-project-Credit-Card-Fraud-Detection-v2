#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER mlflow WITH PASSWORD 'mlflow';
    CREATE DATABASE mlflow;
    GRANT ALL PRIVILEGES ON DATABASE mlflow TO mlflow;
EOSQL

# Conectar a la DB mlflow para asignar permisos al schema public
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "mlflow" <<-EOSQL
    ALTER SCHEMA public OWNER TO mlflow;
    GRANT ALL ON SCHEMA public TO mlflow;
EOSQL
