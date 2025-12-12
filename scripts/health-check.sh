#!/bin/bash

# Script de verificação de saúde dos serviços
# Use: ./scripts/health-check.sh

echo "🔍 Verificando saúde dos serviços..."
echo ""

# Cores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para verificar serviço
check_service() {
    local service_name=$1
    local check_command=$2
    
    echo -n "Verificando $service_name... "
    if eval $check_command > /dev/null 2>&1; then
        echo -e "${GREEN}✓ OK${NC}"
        return 0
    else
        echo -e "${RED}✗ FALHOU${NC}"
        return 1
    fi
}

# Verificar se Docker está rodando
check_service "Docker" "docker info"

# Verificar containers
echo ""
echo "📦 Status dos Containers:"
docker compose ps

echo ""
echo "🌐 Verificando endpoints HTTP:"

# PostgreSQL
check_service "PostgreSQL" "docker compose exec -T postgres pg_isready -U airflow"

# MinIO
check_service "MinIO API" "curl -f http://localhost:9000/minio/health/live"
check_service "MinIO Console" "curl -f http://localhost:9001"

# Airflow
check_service "Airflow Webserver" "curl -f http://localhost:8080/health"

echo ""
echo "📊 Uso de recursos:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"

echo ""
echo "✅ Verificação concluída!"
echo ""
echo "🔗 Acesse os serviços:"
echo "   Airflow: http://localhost:8080 (airflow/airflow)"
echo "   MinIO:   http://localhost:9001 (admin/password123)"
