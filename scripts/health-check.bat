@echo off
REM Script de verificação de saúde dos serviços (Windows)
REM Use: scripts\health-check.bat

echo Verificando saude dos servicos...
echo.

REM Verificar se Docker está rodando
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERRO] Docker nao esta rodando!
    exit /b 1
)
echo [OK] Docker esta rodando

echo.
echo Status dos Containers:
docker compose ps

echo.
echo Verificando endpoints HTTP:

REM MinIO
curl -f http://localhost:9000/minio/health/live >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] MinIO API
) else (
    echo [ERRO] MinIO API nao responde
)

REM Airflow
curl -f http://localhost:8080/health >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] Airflow Webserver
) else (
    echo [ERRO] Airflow Webserver nao responde
)

echo.
echo Uso de recursos:
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"

echo.
echo Verificacao concluida!
echo.
echo Acesse os servicos:
echo    Airflow: http://localhost:8080 (airflow/airflow)
echo    MinIO:   http://localhost:9001 (admin/password123)
