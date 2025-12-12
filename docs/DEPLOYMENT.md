# Deployment em Produção

Este guia fornece instruções para deployment do pipeline em ambiente de produção.

## ⚠️ Pré-requisitos de Produção

### Infraestrutura Mínima
- **CPU**: 4 cores (8 recomendado para Whisper)
- **RAM**: 16GB (32GB para modelo Whisper `large`)
- **Disco**: 100GB SSD (+ espaço para crescimento do Data Lake)
- **Rede**: 100Mbps simétrica

### Software
- Docker Engine 20.10+
- Docker Compose 2.0+
- Sistema Operacional: Ubuntu 22.04 LTS / RHEL 8+

## 🔒 Segurança

### 1. Alterar Todas as Credenciais Padrão

Edite o ficheiro `.env`:

```bash
# Airflow
AIRFLOW_UID=50000
_AIRFLOW_WWW_USER_USERNAME=seu_usuario_admin
_AIRFLOW_WWW_USER_PASSWORD=SenhaForte123!@#

# MinIO
MINIO_ROOT_USER=admin_production
MINIO_ROOT_PASSWORD=MinIOSenhaSegura456!@#

# PostgreSQL
POSTGRES_USER=airflow_prod
POSTGRES_PASSWORD=PostgresSeguro789!@#
POSTGRES_DB=airflow_production
```

### 2. Configurar HTTPS

#### Opção A: Nginx como Reverse Proxy

Crie `nginx.conf`:

```nginx
server {
    listen 443 ssl http2;
    server_name seu-dominio.com;

    ssl_certificate /etc/ssl/certs/seu-cert.crt;
    ssl_certificate_key /etc/ssl/private/seu-cert.key;

    # Airflow
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # MinIO Console
    location /minio/ {
        proxy_pass http://localhost:9001;
    }
}
```

#### Opção B: Traefik (Docker-native)

Adicione ao `docker-compose.yml`:

```yaml
services:
  traefik:
    image: traefik:v2.10
    ports:
      - "443:443"
      - "80:80"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./traefik.yml:/etc/traefik/traefik.yml
```

### 3. Habilitar Autenticação JWT no Airflow

Adicione ao `docker-compose.yml` em `x-airflow-common.environment`:

```yaml
AIRFLOW__API__AUTH_BACKENDS: airflow.api.auth.backend.basic_auth
AIRFLOW__WEBSERVER__SECRET_KEY: "chave-secreta-unica-aqui-256-bits"
AIRFLOW__WEBSERVER__RBAC: "true"
```

## 📊 Persistência de Dados

### Volumes de Produção

Altere o `docker-compose.yml` para usar volumes nomeados:

```yaml
volumes:
  postgres-db-volume:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /mnt/data/postgres
  
  minio-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /mnt/data/minio
```

### Backup Automático

Crie `scripts/backup.sh`:

```bash
#!/bin/bash

BACKUP_DIR="/mnt/backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR

# Backup PostgreSQL
docker compose exec -T postgres pg_dump -U airflow airflow > $BACKUP_DIR/airflow.sql

# Backup MinIO (usando mc - MinIO Client)
docker run --rm \
  --network artigos-ingestao-comocr-transcricao-audio_default \
  -v $BACKUP_DIR:/backup \
  minio/mc:latest \
  mirror myminio/lake-bronze /backup/lake-bronze

# Comprimir
tar -czf $BACKUP_DIR.tar.gz $BACKUP_DIR
rm -rf $BACKUP_DIR

# Manter apenas últimos 7 dias
find /mnt/backups -name "*.tar.gz" -mtime +7 -delete
```

Agende no cron:
```bash
0 2 * * * /app/scripts/backup.sh
```

## 🚀 Deploy

### 1. Clonar o Repositório

```bash
git clone https://github.com/mauropjjr/artigos-ingestao-comocr-transcricao-audio.git
cd artigos-ingestao-comocr-transcricao-audio
```

### 2. Configurar Variáveis de Ambiente

```bash
cp .env.example .env
nano .env  # Edite com credenciais de produção
```

### 3. Ajustar Recursos Docker

Crie/edite `/etc/docker/daemon.json`:

```json
{
  "default-runtime": "runc",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  }
}
```

Reinicie Docker:
```bash
sudo systemctl restart docker
```

### 4. Construir e Iniciar

```bash
# Construir imagens
docker compose build --no-cache

# Iniciar serviços
docker compose up -d

# Verificar logs
docker compose logs -f
```

### 5. Verificar Saúde

```bash
# Usar script de verificação
bash scripts/health-check.sh

# Verificar manualmente
curl http://localhost:8080/health
curl http://localhost:9000/minio/health/live
```

## 📈 Monitorização

### Prometheus + Grafana

Adicione ao `docker-compose.yml`:

```yaml
services:
  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana:latest
    volumes:
      - grafana-data:/var/lib/grafana
    ports:
      - "3000:3000"
    environment:
      GF_SECURITY_ADMIN_PASSWORD: admin
```

### Configuração Prometheus (`prometheus.yml`)

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'airflow'
    static_configs:
      - targets: ['airflow-webserver:8080']
  
  - job_name: 'minio'
    static_configs:
      - targets: ['minio:9000']
```

### Alertas (AlertManager)

```yaml
# alertmanager.yml
route:
  receiver: 'email'

receivers:
  - name: 'email'
    email_configs:
      - to: 'ops@empresa.com'
        from: 'alertas@empresa.com'
        smarthost: 'smtp.gmail.com:587'
        auth_username: 'alertas@empresa.com'
        auth_password: 'senha-app'
```

## 🔄 CI/CD

### GitHub Actions

Crie `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Deploy via SSH
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.PROD_HOST }}
          username: ${{ secrets.PROD_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /app/artigos-ingestao-comocr-transcricao-audio
            git pull origin main
            docker compose build
            docker compose up -d
```

## 🧪 Testes de Carga

### Simular Upload em Massa

```bash
# Criar 100 ficheiros de teste
for i in {1..100}; do
  echo "Documento de teste $i" > test_$i.txt
done

# Upload para MinIO
for file in test_*.txt; do
  docker run --rm \
    --network artigos-ingestao-comocr-transcricao-audio_default \
    -v $(pwd):/data \
    minio/mc:latest \
    cp /data/$file myminio/lake-bronze/
done

# Monitorizar processamento
watch docker compose exec airflow-scheduler airflow dags state 1_ingestao_nao_estruturada
```

## 📋 Checklist de Produção

- [ ] Credenciais alteradas e seguras
- [ ] HTTPS configurado
- [ ] Firewall configurado (portas 80, 443 abertas)
- [ ] Backups automáticos funcionando
- [ ] Monitorização configurada (Prometheus/Grafana)
- [ ] Alertas configurados
- [ ] Logs centralizados (ELK/Loki)
- [ ] Documentação interna atualizada
- [ ] Testes de recuperação de desastre realizados
- [ ] Escalabilidade testada (100+ ficheiros simultâneos)
- [ ] Política de retenção de dados definida
- [ ] Conformidade LGPD/GDPR verificada

## 🆘 Troubleshooting em Produção

### Alto Uso de CPU

```bash
# Identificar processo
docker stats

# Limitar recursos de um serviço
docker update --cpus="2.0" airflow-scheduler
```

### Alto Uso de Memória

```bash
# Ver uso detalhado
docker compose exec airflow-webserver free -h

# Aumentar swap (temporário)
sudo swapon --show
```

### Disco Cheio

```bash
# Limpar logs antigos
docker compose exec airflow-scheduler \
  find /opt/airflow/logs -mtime +30 -delete

# Limpar imagens não usadas
docker image prune -a -f
```

## 📞 Suporte

Para issues de produção:
1. Verificar logs: `docker compose logs -f --tail=100`
2. Consultar `docs/ARCHITECTURE.md`
3. Abrir issue no GitHub com logs completos
4. Contactar: ops@empresa.com
