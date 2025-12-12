import os

# Cliente S3 será inicializado na primeira chamada
_s3_client = None

def _get_s3_client():
    """Lazy initialization do cliente S3."""
    global _s3_client
    if _s3_client is None:
        import boto3
        _s3_client = boto3.client(
            's3',
            endpoint_url='http://minio:9000',
            aws_access_key_id='admin',
            aws_secret_access_key='password123'
        )
    return _s3_client

def process_file(bucket_name, file_key):
    """
    Função principal que decide como processar o ficheiro.
    """
    print(f"A processar ficheiro: {file_key}")
    
    # Obter cliente S3
    s3_client = _get_s3_client()
    
    # 1. Descarregar o ficheiro do Bronze para local temporário
    local_path = f"/tmp/{file_key.split('/')[-1]}"
    s3_client.download_file(bucket_name, file_key, local_path)
    
    extracted_text = ""
    file_ext = local_path.split('.')[-1].lower()

    # 2. Lógica de Decisão
    if file_ext in ['pdf', 'png', 'jpg', 'jpeg']:
        extracted_text = _run_ocr(local_path)
    elif file_ext in ['mp3', 'wav', 'mp4', 'm4a']:
        extracted_text = _run_transcription(local_path)
    else:
        return "Formato não suportado"

    # 3. Guardar no Silver (Processed) como ficheiro de texto
    output_key = file_key.replace('.', '_') + ".txt"
    s3 = _get_s3_client()
    s3.put_object(
        Bucket='lake-silver',
        Key=output_key,
        Body=extracted_text.encode('utf-8')
    )
    
    # Limpeza
    os.remove(local_path)
    return f"Sucesso! Texto guardado em lake-silver/{output_key}"

def _run_ocr(file_path):
    """Executa OCR em imagens ou PDFs."""
    # Imports lazy para evitar timeout
    import pytesseract
    from pdf2image import convert_from_path
    
    print("A iniciar OCR...")
    # Se for PDF, converte em imagens primeiro
    if file_path.endswith('.pdf'):
        images = convert_from_path(file_path)
        full_text = ""
        for i, img in enumerate(images):
            # lang='por' usa o dicionário de Português
            text = pytesseract.image_to_string(img, lang='por')
            full_text += f"\n--- Pagina {i+1} ---\n{text}"
        return full_text
    else:
        return pytesseract.image_to_string(file_path, lang='por')

def _run_transcription(file_path):
    """Executa transcrição de áudio usando Whisper."""
    # Import lazy para evitar timeout no DagBag
    import whisper
    
    print("A iniciar Transcrição de Áudio (Whisper)...")
    # Carrega o modelo 'base' (equilíbrio entre velocidade e precisão)
    # Num ambiente de produção real com GPU, usaria 'large'
    model = whisper.load_model("base") 
    result = model.transcribe(file_path, language='pt')
    return result["text"]
