#!/bin/bash

# ============================================================================
# Script de Inicialização Rápida
# Projeto: Ingestão com OCR e Transcrição de Áudio
# ============================================================================

set -e  # Sair se houver erro

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║   🚀 Inicializando Projeto de Ingestão Inteligente            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Verificar se Docker está instalado
if ! command -v docker &> /dev/null; then
    echo "❌ Docker não encontrado. Por favor, instale o Docker primeiro."
    echo "   https://docs.docker.com/get-docker/"
    exit 1
fi

if ! command -v docker compose &> /dev/null; then
    echo "❌ Docker Compose não encontrado. Por favor, instale o Docker Compose."
    echo "   https://docs.docker.com/compose/install/"
    exit 1
fi

echo "✅ Docker instalado: $(docker --version)"
echo "✅ Docker Compose instalado: $(docker compose version)"
echo ""

# Verificar se .env existe
if [ ! -f .env ]; then
    echo "📝 Criando ficheiro .env a partir do template..."
    cp .env.example .env
    echo "✅ Ficheiro .env criado"
else
    echo "✅ Ficheiro .env já existe"
fi

echo ""
echo "🔧 Construindo imagens Docker (pode demorar 5-10 minutos)..."
docker compose build

echo ""
echo "🚀 Iniciando serviços..."
docker compose up -d

echo ""
echo "⏳ Aguardando serviços iniciarem (60 segundos)..."
sleep 60

echo ""
echo "🔍 Verificando saúde dos serviços..."
echo ""

# Verificar MinIO
if curl -sf http://localhost:9000/minio/health/live > /dev/null 2>&1; then
    echo "✅ MinIO está saudável"
else
    echo "⚠️  MinIO ainda não respondeu (pode demorar mais alguns segundos)"
fi

# Verificar Airflow
if curl -sf http://localhost:8080/health > /dev/null 2>&1; then
    echo "✅ Airflow está saudável"
else
    echo "⚠️  Airflow ainda não respondeu (pode demorar mais alguns segundos)"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                 ✅ PROJETO INICIADO COM SUCESSO!               ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "🌐 Acesse os serviços:"
echo ""
echo "   📊 Airflow UI:"
echo "      URL: http://localhost:8080"
echo "      User: airflow"
echo "      Password: airflow"
echo ""
echo "   🗄️  MinIO Console:"
echo "      URL: http://localhost:9001"
echo "      User: admin"
echo "      Password: password123"
echo ""
echo "📚 Próximos passos:"
echo "   1. Acesse o MinIO Console e faça upload de ficheiros para 'lake-bronze'"
echo "   2. Acesse o Airflow UI e ative a DAG '1_ingestao_nao_estruturada'"
echo "   3. Aguarde o processamento (ou force manualmente)"
echo "   4. Verifique os resultados em 'lake-silver'"
echo ""
echo "📖 Documentação:"
echo "   • README.md           - Guia completo"
echo "   • QUICKSTART.md       - Início rápido"
echo "   • docs/FAQ.md         - Perguntas frequentes"
echo "   • docs/VISUAL_GUIDE.md - Diagramas visuais"
echo ""
echo "🛠️  Comandos úteis:"
echo "   • docker compose logs -f            - Ver logs"
echo "   • docker compose ps                 - Status dos containers"
echo "   • docker compose down               - Parar serviços"
echo "   • docker compose restart            - Reiniciar serviços"
echo "   • bash scripts/health-check.sh      - Verificar saúde"
echo ""
echo "❓ Precisa de ajuda? Consulte docs/FAQ.md ou abra uma issue no GitHub"
echo ""
