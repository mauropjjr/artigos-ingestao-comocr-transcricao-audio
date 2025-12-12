@echo off
REM ============================================================================
REM Script de Inicializacao Rapida (Windows)
REM Projeto: Ingestao com OCR e Transcricao de Audio
REM ============================================================================

echo ========================================================================
echo    Inicializando Projeto de Ingestao Inteligente
echo ========================================================================
echo.

REM Verificar Docker
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERRO] Docker nao encontrado. Instale o Docker Desktop primeiro.
    echo        https://docs.docker.com/desktop/install/windows-install/
    exit /b 1
)

echo [OK] Docker instalado
docker --version

docker compose version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERRO] Docker Compose nao encontrado.
    exit /b 1
)

echo [OK] Docker Compose instalado
docker compose version
echo.

REM Verificar .env
if not exist .env (
    echo [INFO] Criando ficheiro .env...
    copy .env.example .env >nul
    echo [OK] Ficheiro .env criado
) else (
    echo [OK] Ficheiro .env ja existe
)

echo.
echo [INFO] Construindo imagens Docker (pode demorar 5-10 minutos)...
docker compose build

echo.
echo [INFO] Iniciando servicos...
docker compose up -d

echo.
echo [INFO] Aguardando servicos iniciarem (60 segundos)...
timeout /t 60 /nobreak >nul

echo.
echo [INFO] Verificando saude dos servicos...
echo.

REM Verificar MinIO
curl -sf http://localhost:9000/minio/health/live >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] MinIO esta saudavel
) else (
    echo [AVISO] MinIO ainda nao respondeu
)

REM Verificar Airflow
curl -sf http://localhost:8080/health >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] Airflow esta saudavel
) else (
    echo [AVISO] Airflow ainda nao respondeu
)

echo.
echo ========================================================================
echo                  PROJETO INICIADO COM SUCESSO!
echo ========================================================================
echo.
echo Acesse os servicos:
echo.
echo    Airflow UI:
echo       URL: http://localhost:8080
echo       User: airflow
echo       Password: airflow
echo.
echo    MinIO Console:
echo       URL: http://localhost:9001
echo       User: admin
echo       Password: password123
echo.
echo Proximos passos:
echo    1. Acesse o MinIO Console e faca upload de ficheiros
echo    2. Acesse o Airflow UI e ative a DAG
echo    3. Aguarde o processamento
echo    4. Verifique os resultados em 'lake-silver'
echo.
echo Documentacao:
echo    README.md
echo    QUICKSTART.md
echo    docs\FAQ.md
echo.
echo Comandos uteis:
echo    docker compose logs -f      - Ver logs
echo    docker compose ps           - Status
echo    docker compose down         - Parar
echo    scripts\health-check.bat    - Verificar saude
echo.
pause
