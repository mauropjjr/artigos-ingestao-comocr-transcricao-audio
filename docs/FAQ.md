# FAQ - Perguntas Frequentes

## 🚀 Instalação e Setup

### P: Quanto tempo demora a primeira execução?
**R:** Entre 5-10 minutos. O Docker precisa descarregar imagens (~2GB) e o Whisper baixa modelos (~140MB).

### P: O projeto funciona no Windows?
**R:** Sim! Use Docker Desktop para Windows. Os scripts `.bat` estão incluídos para substituir scripts `.sh`.

### P: Posso usar no macOS com chip M1/M2?
**R:** Sim, mas pode demorar mais na construção. Use `--platform linux/amd64` se tiver problemas:
```bash
docker compose build --platform linux/amd64
```

### P: Preciso de GPU?
**R:** Não é obrigatório. O projeto usa o modelo Whisper `base` (CPU-only). Para produção pesada, GPU acelera 10-20x.

## 💾 Armazenamento e Dados

### P: Onde os ficheiros ficam guardados?
**R:** 
- **Originais**: MinIO bucket `lake-bronze`
- **Processados**: MinIO bucket `lake-silver` (texto puro)
- **Metadados**: PostgreSQL

### P: Como posso ver os ficheiros processados?
**R:** 
1. Acesse http://localhost:9001
2. Login: `admin` / `password123`
3. Navegue até bucket `lake-silver`

### P: Quanto espaço em disco preciso?
**R:**
- **Mínimo**: 10GB (sistema + dados de teste)
- **Recomendado**: 50GB+ para uso contínuo
- **Produção**: 100GB+ dependendo do volume

### P: Os ficheiros originais são apagados após processamento?
**R:** Não! Eles permanecem em `lake-bronze`. Apenas o texto extraído é salvo em `lake-silver`.

## 🎯 Processamento

### P: Quais formatos são suportados?
**R:**
- **Imagens/PDFs**: PDF, PNG, JPG, JPEG
- **Áudio**: MP3, WAV, M4A, MP4

### P: Como adiciono suporte para DOCX?
**R:** Adicione ao `ingestion_brain.py`:
```python
import docx

def _extract_docx(file_path):
    doc = docx.Document(file_path)
    return '\n'.join([p.text for p in doc.paragraphs])
```

### P: O OCR funciona com português?
**R:** Sim! Usamos `tesseract-ocr-por` instalado no Dockerfile.

### P: A transcrição de áudio suporta outros idiomas?
**R:** Sim! Altere em `ingestion_brain.py`:
```python
result = model.transcribe(file_path, language='en')  # Inglês
result = model.transcribe(file_path, language='es')  # Espanhol
```

### P: Quanto tempo demora a processar um ficheiro?
**R:**
- **Imagem (1 página)**: 2-5 segundos
- **PDF (10 páginas)**: 20-50 segundos
- **Áudio (5 minutos)**: 30-60 segundos (CPU)

## 🔧 Configuração

### P: Como altero a frequência de execução da DAG?
**R:** Edite `dags/ingestion_pipeline.py`:
```python
schedule_interval='*/5 * * * *'  # A cada 5 minutos
schedule_interval='@hourly'       # A cada hora
schedule_interval='@daily'        # Diariamente
```

### P: Posso processar ficheiros imediatamente (sem esperar 30 min)?
**R:** Sim! No Airflow UI, clique em "Trigger DAG" manualmente.

### P: Como adiciono mais memória ao Whisper?
**R:** No `docker-compose.yml`, adicione:
```yaml
services:
  airflow-scheduler:
    deploy:
      resources:
        limits:
          memory: 8G
```

## 🐛 Problemas Comuns

### P: Erro "Tesseract not found"
**R:**
```bash
# Reconstruir imagem
docker compose down
docker compose build --no-cache
docker compose up -d
```

### P: MinIO não aceita credenciais
**R:** Verifique se usou as corretas:
- **User**: `admin`
- **Password**: `password123`
- Se alterou `.env`, use as novas credenciais

### P: DAG não aparece no Airflow
**R:**
1. Verifique logs: `docker compose logs airflow-scheduler`
2. Sintaxe Python correta? `python dags/ingestion_pipeline.py`
3. Aguarde 30 segundos para o scheduler detectar

### P: Erro "Out of Memory" durante transcrição
**R:**
1. Use modelo menor: `whisper.load_model("tiny")`
2. Aumente RAM Docker (Settings → Resources → 8GB)
3. Processe áudios mais curtos (<10 min)

### P: Container fica reiniciando constantemente
**R:**
```bash
# Ver logs do problema
docker compose logs [nome-do-container]

# Causas comuns:
# - Porta já em uso (altere no docker-compose.yml)
# - RAM insuficiente
# - Erro de sintaxe no código Python
```

## 🔒 Segurança

### P: É seguro usar em produção com credenciais padrão?
**R:** **NÃO!** Sempre altere as credenciais em `.env` para produção.

### P: Como habilito HTTPS?
**R:** Veja o guia completo em `docs/DEPLOYMENT.md`. Use Nginx ou Traefik como reverse proxy.

### P: Os dados são encriptados?
**R:** Por padrão, não. Para encriptação:
1. **Em trânsito**: Use HTTPS/TLS
2. **Em repouso**: Configure encriptação no MinIO

## 📊 Monitorização

### P: Como vejo logs de uma execução específica?
**R:** No Airflow UI:
1. DAGs → `1_ingestao_nao_estruturada`
2. Clique na execução (círculo colorido)
3. Clique na tarefa → "Log"

### P: Como sei se o processamento falhou?
**R:**
- **Airflow UI**: Tarefa fica vermelha
- **Email**: Configure alertas no Airflow
- **Logs**: Pesquise por "ERROR" ou "FAILED"

### P: Posso ver métricas de performance?
**R:** Adicione Prometheus + Grafana (veja `docs/DEPLOYMENT.md`).

## 🚀 Performance

### P: Como processar 1000+ ficheiros mais rápido?
**R:**
1. Use múltiplos workers Airflow (Celery Executor)
2. Processe em paralelo (configure `max_active_runs`)
3. Use GPU para Whisper
4. Escale horizontalmente com Kubernetes

### P: Posso usar na cloud (AWS, Azure, GCP)?
**R:** Sim! Substitua:
- **MinIO** → S3/Azure Blob/GCS
- **PostgreSQL** → RDS/Azure DB/Cloud SQL
- **Airflow** → Managed Airflow (MWAA, Cloud Composer)

## 📚 Desenvolvimento

### P: Como contribuo para o projeto?
**R:** Veja `CONTRIBUTING.md`. Passos básicos:
1. Fork no GitHub
2. Crie branch: `git checkout -b feature/minha-feature`
3. Commit: `git commit -m "feat: adicionar X"`
4. Pull Request

### P: Como adiciono testes automatizados?
**R:** Crie `tests/test_ingestion.py`:
```python
import pytest
from dags.scripts.ingestion_brain import process_file

def test_process_pdf():
    result = process_file('lake-bronze', 'test.pdf')
    assert 'Sucesso' in result
```

Execute: `pytest tests/`

### P: Posso usar com outro orquestrador (Prefect, Dagster)?
**R:** Sim! A lógica está em `ingestion_brain.py` (independente do Airflow).

## 💰 Custos

### P: Quanto custa rodar localmente?
**R:** Grátis! Apenas custos de eletricidade do seu computador.

### P: Quanto custa na cloud?
**R:** Depende do volume. Estimativa AWS (1000 ficheiros/mês):
- **EC2 (t3.large)**: ~$60/mês
- **S3**: ~$5/mês
- **RDS**: ~$30/mês
- **Total**: ~$100/mês

### P: Há custos de API (Whisper, Tesseract)?
**R:** Não! Ambos são open-source e rodam localmente.

## 🔄 Migração e Integração

### P: Como migro dados de outro sistema?
**R:** Use o MinIO Client (`mc`):
```bash
mc cp --recursive /caminho/antigo minio/lake-bronze
```

### P: Posso integrar com banco de dados existente?
**R:** Sim! Após processar, salve metadados:
```python
import psycopg2
conn = psycopg2.connect("dbname=meu_banco")
cur = conn.cursor()
cur.execute("INSERT INTO documentos (nome, texto) VALUES (%s, %s)", 
            (file_name, extracted_text))
```

### P: Como conecto a um sistema legado?
**R:** Crie uma DAG adicional para polling:
- FTP/SFTP: `apache-airflow-providers-sftp`
- SMB/CIFS: `smbprotocol`
- Email (IMAP): `apache-airflow-providers-imap`

## 📞 Suporte

### P: Onde consigo ajuda?
**R:**
1. Leia a documentação (`README.md`, `docs/`)
2. Pesquise issues no GitHub
3. Abra nova issue com logs completos
4. Consulte [Apache Airflow Docs](https://airflow.apache.org)

### P: Há suporte comercial disponível?
**R:** Este é um projeto open-source. Para suporte enterprise, contacte o autor.

---

**Não encontrou sua pergunta?** Abra uma issue no GitHub!
