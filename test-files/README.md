# Ficheiros de Exemplo para Teste

Este diretório contém ficheiros de exemplo para testar o pipeline de ingestão.

## Como usar

1. Inicie o projeto: `docker compose up -d`
2. Aceda ao MinIO Console: http://localhost:9001
3. Login: `admin` / `password123`
4. Navegue até o bucket `lake-bronze`
5. Faça upload dos ficheiros deste diretório
6. Aguarde 30 minutos ou force a execução da DAG no Airflow
7. Verifique os resultados em `lake-silver`

## Ficheiros de Teste

Para testar o pipeline, você pode usar:

### PDFs
- Qualquer documento PDF digitalizado
- Notas fiscais escaneadas
- Contratos fotografados e convertidos em PDF

### Imagens
- `.jpg`, `.jpeg`, `.png` de documentos
- Screenshots de texto
- Fotos de documentos físicos

### Áudio
- `.mp3` de reuniões gravadas
- `.wav` de entrevistas
- `.m4a` de gravações de telemóvel

## Criar Ficheiros de Teste

### Nota Fiscal (PDF)
Crie um documento simples no Word/LibreOffice e salve como PDF:

```
NOTA FISCAL
Série: 001  Número: 12345
Data: 15/03/1998

Razão Social: EMPRESA XYZ LTDA
CNPJ: 12.345.678/0001-99

DESCRIÇÃO          VALOR
Consultoria Fiscal  R$ 1.500,00
ICMS (18%)          R$ 270,00
TOTAL               R$ 1.770,00
```

### Áudio de Teste
Grave um áudio curto (30-60 segundos) em português falando sobre qualquer tópico de negócios.

Exemplo de roteiro:
> "Este é um teste do sistema de transcrição. Estamos avaliando a qualidade da conversão de áudio em texto para documentos jurídicos e contabilísticos. A empresa está localizada em São Paulo e atende clientes em todo Brasil."
