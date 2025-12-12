# Guia Visual - Fluxo de Dados

```
═══════════════════════════════════════════════════════════════════════════════
                         PIPELINE DE INGESTÃO INTELIGENTE                       
═══════════════════════════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────────────────────┐
│                                  FASE 1: INPUT                               │
│                                                                              │
│    👤 Utilizador                                                             │
│     │                                                                        │
│     ├─→ 📄 Nota Fiscal Digitalizada (PDF)                                   │
│     ├─→ 🎤 Reunião Gravada (MP3)                                            │
│     ├─→ 📷 Foto de Contrato (JPG)                                           │
│     └─→ 📑 Documento Escaneado (PNG)                                        │
│                                                                              │
│                         ↓ Upload via MinIO Console                          │
│                                                                              │
│    ┌─────────────────────────────────────────────────────────────┐         │
│    │              🗄️  MinIO - Bucket "lake-bronze"              │         │
│    │                  (Raw/Immutable Storage)                     │         │
│    └─────────────────────────────────────────────────────────────┘         │
└─────────────────────────────────────────────────────────────────────────────┘

                                      ↓

┌─────────────────────────────────────────────────────────────────────────────┐
│                            FASE 2: ORQUESTRAÇÃO                              │
│                                                                              │
│    ⏰ Airflow Scheduler (a cada 30 minutos)                                 │
│     │                                                                        │
│     ├─→ 🔍 Escaneia bucket "lake-bronze"                                    │
│     ├─→ 📋 Lista ficheiros novos                                            │
│     └─→ 🚀 Dispara tarefa: process_bronze_files                             │
│                                                                              │
│    ┌─────────────────────────────────────────────────────────────┐         │
│    │           🎯 DAG: 1_ingestao_nao_estruturada                │         │
│    │              Task: list_and_process_files()                  │         │
│    └─────────────────────────────────────────────────────────────┘         │
└─────────────────────────────────────────────────────────────────────────────┘

                                      ↓

┌─────────────────────────────────────────────────────────────────────────────┐
│                          FASE 3: DECISÃO INTELIGENTE                         │
│                                                                              │
│    🧠 ingestion_brain.py - process_file()                                   │
│     │                                                                        │
│     ├─→ 📦 Download ficheiro para /tmp/                                     │
│     ├─→ 🔎 Detectar extensão (.pdf, .mp3, .jpg, etc.)                       │
│     └─→ 🎯 Rotear para processador correto                                  │
│                                                                              │
│         ┌────────────────┐                                                  │
│         │   Roteador     │                                                  │
│         └────────┬───────┘                                                  │
│                  │                                                           │
│        ┌─────────┴─────────┐                                                │
│        ↓                   ↓                                                 │
│   ┌─────────┐        ┌──────────┐                                          │
│   │ .pdf    │        │ .mp3     │                                          │
│   │ .png    │        │ .wav     │                                          │
│   │ .jpg    │        │ .m4a     │                                          │
│   └────┬────┘        └────┬─────┘                                          │
└────────┼──────────────────┼──────────────────────────────────────────────────┘
         │                  │
         ↓                  ↓

┌─────────────────────┐    ┌─────────────────────┐
│   PROCESSADOR OCR   │    │ PROCESSADOR ÁUDIO   │
├─────────────────────┤    ├─────────────────────┤
│                     │    │                     │
│  📄 PDF?            │    │  🎵 Carregar áudio  │
│   ├─→ pdf2image    │    │                     │
│   ├─→ PIL Image    │    │  🤖 OpenAI Whisper  │
│   └─→ ↓            │    │   ├─→ Modelo: base  │
│                     │    │   ├─→ Language: pt  │
│  🖼️  Tesseract OCR  │    │   └─→ Transcrever  │
│   ├─→ lang='por'   │    │                     │
│   ├─→ Página 1...  │    │  📝 Texto gerado    │
│   ├─→ Página 2...  │    │                     │
│   └─→ Página N     │    │                     │
│                     │    │                     │
│  📝 Texto extraído  │    │                     │
│                     │    │                     │
└──────────┬──────────┘    └──────────┬──────────┘
           │                          │
           └────────────┬─────────────┘
                        ↓

┌─────────────────────────────────────────────────────────────────────────────┐
│                           FASE 4: PERSISTÊNCIA                               │
│                                                                              │
│    💾 s3_client.put_object()                                                │
│     │                                                                        │
│     ├─→ Bucket: "lake-silver"                                               │
│     ├─→ Key: "nota_fiscal_1998_pdf.txt"                                     │
│     ├─→ Body: texto_extraído.encode('utf-8')                                │
│     └─→ ✅ Upload completo                                                  │
│                                                                              │
│    ┌─────────────────────────────────────────────────────────────┐         │
│    │              🗃️  MinIO - Bucket "lake-silver"              │         │
│    │                  (Processed Text Storage)                    │         │
│    │                                                              │         │
│    │  📄 nota_fiscal_1998_pdf.txt                                │         │
│    │  📄 reuniao_cliente_silva_mp3.txt                           │         │
│    │  📄 contrato_assinado_jpg.txt                               │         │
│    └─────────────────────────────────────────────────────────────┘         │
└─────────────────────────────────────────────────────────────────────────────┘

                                      ↓

┌─────────────────────────────────────────────────────────────────────────────┐
│                             FASE 5: CONSUMO                                  │
│                                                                              │
│    📊 Casos de Uso:                                                         │
│                                                                              │
│    1️⃣  Busca por Keyword                                                    │
│        grep -r "ICMS" lake-silver/                                          │
│                                                                              │
│    2️⃣  Análise de Sentimento                                                │
│        python sentiment_analysis.py --input lake-silver/                    │
│                                                                              │
│    3️⃣  Vetorização (Próximo Artigo) 🚀                                      │
│        sentence-transformers → Vector DB → RAG                              │
│                                                                              │
│    4️⃣  Dashboard de Metadados                                               │
│        Grafana + PostgreSQL (logs do Airflow)                               │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════════════════════════
                             MÉTRICAS DE EXEMPLO                                
═══════════════════════════════════════════════════════════════════════════════

┌────────────────────────┬──────────────────────────────────────────────────┐
│ Tipo de Ficheiro       │ Tempo Médio de Processamento (CPU)               │
├────────────────────────┼──────────────────────────────────────────────────┤
│ Imagem JPG (1 pág)     │ ████░░░░░░░░░░░░░░░░  2-5 segundos              │
│ PDF (10 páginas)       │ ██████████░░░░░░░░░░  20-50 segundos             │
│ Áudio MP3 (5 min)      │ ████████████░░░░░░░░  30-60 segundos             │
│ PDF Complexo (50 pág)  │ ████████████████████  3-5 minutos                │
└────────────────────────┴──────────────────────────────────────────────────┘

┌────────────────────────┬──────────────────────────────────────────────────┐
│ Recurso                │ Uso Típico                                       │
├────────────────────────┼──────────────────────────────────────────────────┤
│ CPU                    │ ████████░░░░░░░░░░░░  40-60% (durante proc.)     │
│ RAM                    │ ██████░░░░░░░░░░░░░░  3-5 GB (Whisper base)      │
│ Disco (por 1000 docs)  │ ████░░░░░░░░░░░░░░░░  2-10 GB                    │
│ Throughput             │ ████████████████████  50-100 ficheiros/hora      │
└────────────────────────┴──────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════════════════════════
                           COMPONENTES DO SISTEMA                               
═══════════════════════════════════════════════════════════════════════════════

    ┌─────────────────────────────────────────────────────────────────┐
    │                      🖥️  Sua Máquina / Servidor                 │
    │                                                                  │
    │  ┌────────────────────────────────────────────────────────────┐ │
    │  │                    🐳 Docker Engine                        │ │
    │  │                                                            │ │
    │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │ │
    │  │  │   Airflow    │  │   MinIO      │  │  PostgreSQL  │   │ │
    │  │  │              │  │              │  │              │   │ │
    │  │  │  Scheduler   │  │  S3 API      │  │  Metadados   │   │ │
    │  │  │  Webserver   │  │  Console UI  │  │  Airflow     │   │ │
    │  │  │              │  │              │  │              │   │ │
    │  │  │  Port: 8080  │  │  Port: 9000  │  │  Port: 5432  │   │ │
    │  │  └──────────────┘  └──────────────┘  └──────────────┘   │ │
    │  │                                                            │ │
    │  │  ┌────────────────────────────────────────────────────┐  │ │
    │  │  │         📦 Volumes (Persistência)                  │  │ │
    │  │  │  • postgres-db-volume  (Base de dados)             │  │ │
    │  │  │  • minio-data          (Data Lake)                 │  │ │
    │  │  │  • airflow-logs        (Logs)                      │  │ │
    │  │  └────────────────────────────────────────────────────┘  │ │
    │  └────────────────────────────────────────────────────────────┘ │
    └─────────────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════════════════════════
                        EXEMPLO DE FICHEIRO PROCESSADO                          
═══════════════════════════════════════════════════════════════════════════════

INPUT (lake-bronze/nota_fiscal.pdf):
┌─────────────────────────────────────┐
│                                     │
│        [Imagem escaneada]           │
│      Texto borrado e inclinado      │
│                                     │
└─────────────────────────────────────┘

                    ↓ Tesseract OCR

OUTPUT (lake-silver/nota_fiscal_pdf.txt):
┌─────────────────────────────────────┐
│ --- Pagina 1 ---                    │
│ NOTA FISCAL                         │
│ Série: 001  Número: 12345           │
│ Data: 15/03/1998                    │
│                                     │
│ Razão Social: EMPRESA XYZ LTDA      │
│ CNPJ: 12.345.678/0001-99            │
│                                     │
│ DESCRIÇÃO          VALOR            │
│ Consultoria Fiscal  R$ 1.500,00     │
│ ICMS (18%)          R$ 270,00       │
│ TOTAL               R$ 1.770,00     │
└─────────────────────────────────────┘

═══════════════════════════════════════════════════════════════════════════════
```

## Legenda de Ícones

| Ícone | Significado |
|-------|-------------|
| 📄 | Documento/PDF |
| 🎤 | Áudio/Gravação |
| 📷 | Imagem/Foto |
| 🗄️ | Armazenamento |
| ⏰ | Agendamento/Timer |
| 🔍 | Busca/Scan |
| 🧠 | Lógica/Decisão |
| 🤖 | IA/Machine Learning |
| 💾 | Persistência/Salvar |
| ✅ | Sucesso |
| ⚠️ | Aviso |
| 🚀 | Deploy/Execução |
| 📊 | Análise/Métricas |
| 🐳 | Docker |
| 🖥️ | Servidor/Máquina |
