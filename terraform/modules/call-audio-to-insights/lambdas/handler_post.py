import os, json, boto3, re
from urllib.parse import urlparse

s3 = boto3.client("s3")
comprehend = boto3.client("comprehend")
polly = boto3.client("polly")
bedrock = boto3.client("bedrock-runtime")  # requiere permisos/region habilitada

OUTPUTS_BUCKET  = os.environ["OUTPUTS_BUCKET"]
BEDROCK_MODELID = os.environ["BEDROCK_MODELID"]

def _extract_text_from_transcript(transcript_json):
    try:
        return transcript_json["results"]["transcripts"][0]["transcript"]
    except Exception:
        return ""

def lambda_handler(event, context):
    bucket = OUTPUTS_BUCKET
    key    = event["TranscriptionJobName"] + ".json"
    print(f"Processing transcription job result s3://{bucket}/{key}")

    obj = s3.get_object(Bucket=bucket, Key=key)
    transcript_json = json.loads(obj["Body"].read())
    text = _extract_text_from_transcript(transcript_json)
    if not text:
        return {"error": "Empty transcript"}

    # 1) Sentimiento
    senti = comprehend.detect_sentiment(Text=text[:4500], LanguageCode="es")

    # 2) Resumen con Bedrock (Claude Haiku)
    prompt = f"""
    Eres un analista de atención al cliente.
    Con base en el siguiente texto de una llamada telefónica en español, quiero que:
    1) Resumas la llamada en máximo 3 viñetas.
    2) Propongas UNA acción concreta para el negocio.
    3) Clasifiques si la llamada es de carácter PERSONAL o de NEGOCIOS.

    Responde **EXCLUSIVAMENTE** con un JSON válido con esta estructura, los valores del json deben ser **SOLAMENTE** cadenas de texto:

    {{
    "summary": "<resumen en español>",
    "suggested_action": "<acción recomendada>",
    "call_type": "<personal|negocios>"
    }}

    Texto de la llamada:
    \"\"\"{text}\"\"\" 
    """

    response = bedrock.invoke_model(
        modelId=BEDROCK_MODELID,
        body=json.dumps({
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 512,
            "temperature": 0.3,
            "messages": [
                {
                    "role": "user",
                    "content": prompt
                }
            ]
        }),
        contentType="application/json",
        accept="application/json"
    )

    model_response = json.loads(response["body"].read())   
    output = json.loads(model_response["content"][0]["text"].strip())
    print(f"Bedrock model output: {output}")

    # normalizar
    if output["call_type"] not in ["personal", "negocios"]:
        output["call_type"] = "desconocido"

    is_personal_call = (output["call_type"] == "personal")
    # 3) Audio con Polly (voz Lucia)
    speech = polly.synthesize_speech(Text=output["summary"][:3000], OutputFormat="mp3", VoiceId="Lucia")
    audio_key = f"outputs/audio/{event['TranscriptionJobName']}.mp3"
    s3.put_object(Body=speech["AudioStream"].read(), Bucket=OUTPUTS_BUCKET, Key=audio_key)

    # 4) Guardar resultado JSON final (sentimiento + resumen + paths)
    result = {
        "transcription_job": event.get("TranscriptionJobName"),
        "sentiment": senti,
        "summary": output["summary"],
        "suggested_action": output["suggested_action"],
        "call_type": output["call_type"],             
        "is_personal_call": is_personal_call, # True si se clasificó como personal
        "transcript_s3": f"s3://{bucket}/{key}",
        "audio_s3": f"s3://{OUTPUTS_BUCKET}/{audio_key}"
    }
    result_key = f"outputs/json/{event['TranscriptionJobName']}.json"
    s3.put_object(
        Bucket=OUTPUTS_BUCKET,
        Key=result_key,
        Body=json.dumps(result, ensure_ascii=False).encode("utf-8"),
        ContentType="application/json"
    )

    return {"ok": True, "result_key": result_key}
