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
    """Executa OCR em imagens ou PDFs com otimizações para ficheiros grandes."""
    # Imports lazy para evitar timeout
    import pytesseract
    from pdf2image import convert_from_path
    from concurrent.futures import ThreadPoolExecutor, as_completed
    import time
    
    print("A iniciar OCR...")
    start_time = time.time()
    
    # Se for PDF, converte em imagens primeiro
    if file_path.endswith('.pdf'):
        # Converter páginas em lotes para economizar memória
        print("A converter PDF em imagens...")
        
        # Processar em lotes de 5 páginas para evitar sobrecarga de memória
        full_text = ""
        first_page = 1
        last_page = None
        batch_size = 5
        page_num = 1
        
        while True:
            try:
                # Converter lote de páginas
                images = convert_from_path(
                    file_path,
                    first_page=first_page,
                    last_page=first_page + batch_size - 1 if last_page is None else min(first_page + batch_size - 1, last_page),
                    dpi=150  # Reduzir DPI para acelerar processamento
                )
                
                if not images:
                    break
                
                # Processar páginas do lote
                for i, img in enumerate(images):
                    elapsed = time.time() - start_time
                    print(f"A processar página {page_num}... (tempo decorrido: {elapsed:.1f}s)")
                    
                    # lang='por' usa o dicionário de Português
                    # config para otimizar velocidade
                    text = pytesseract.image_to_string(
                        img, 
                        lang='por',
                        config='--oem 1 --psm 3'  # OEM 1 = LSTM neural net, PSM 3 = fully automatic page segmentation
                    )
                    full_text += f"\n--- Página {page_num} ---\n{text}"
                    page_num += 1
                
                # Avançar para próximo lote
                first_page += batch_size
                
                # Se retornou menos imagens que o batch_size, chegamos ao fim
                if len(images) < batch_size:
                    break
                    
            except Exception as e:
                # Fim do PDF ou erro
                if "Image list must contain at least one image" in str(e):
                    break
                print(f"Aviso: Erro ao processar lote começando na página {first_page}: {str(e)}")
                break
        
        total_time = time.time() - start_time
        print(f"OCR concluído em {total_time:.1f}s. Total de páginas: {page_num - 1}")
        return full_text
    else:
        # Para imagens simples
        from PIL import Image
        img = Image.open(file_path)
        text = pytesseract.image_to_string(
            img, 
            lang='por',
            config='--oem 1 --psm 3'
        )
        elapsed = time.time() - start_time
        print(f"OCR concluído em {elapsed:.1f}s")
        return text

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
