import os, json, boto3, re
from urllib.parse import urlparse

# Added Metrics
from aws_lambda_powertools import Metrics
from aws_lambda_powertools.metrics import MetricUnit
from aws_lambda_powertools.utilities.typing import LambdaContext

s3 = boto3.client("s3")
comprehend = boto3.client("comprehend")
polly = boto3.client("polly")
bedrock = boto3.client("bedrock-runtime") 

dynamodb = boto3.resource("dynamodb")
DYNAMO_DB_TABLE = os.environ.get("DYNAMO_DB_TABLE", "call-insights")
table = dynamodb.Table(DYNAMO_DB_TABLE)

OUTPUTS_BUCKET  = os.environ["OUTPUTS_BUCKET"]
BEDROCK_MODELID = os.environ["BEDROCK_MODELID"]

# Initialize Metrics
metrics = Metrics(service="call-insights", namespace=os.environ["PROJECT_NAME"])

def _extract_text_from_transcript(transcript_json):
    try:
        return transcript_json["results"]["transcripts"][0]["transcript"]
    except Exception:
        return ""

@metrics.log_metrics

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
    Eres un analista de atención al cliente de una importante empresa de envio de paquetería.
    Con base en el siguiente texto de una llamada telefónica en español, quiero que:
    1) Resumas la llamada en máximo 3 viñetas.
    2) Propongas UNA acción concreta para el negocio.
    3) Clasifiques si la llamada es de carácter PERSONAL o de NEGOCIOS. Una llamada personal involucra mencionar amigos, familia o temas no relacionados al negocio

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
    if output["call_type"] not in ["personal", "business"]:
        output["call_type"] = "desconocido"

    is_personal_call = (output["call_type"] == "personal")
    # 3) Audio con Polly (voz Lucia)
    speech = polly.synthesize_speech(Text=output["summary"][:3000], OutputFormat="mp3", VoiceId="Lucia")
    audio_key = f"outputs/audio/{event['TranscriptionJobName']}.mp3"
    s3.put_object(Body=speech["AudioStream"].read(), Bucket=OUTPUTS_BUCKET, Key=audio_key)

    # 4) Guardar resultado JSON final (sentimiento + resumen + paths)
    result = {
        "transcription_job": event.get("TranscriptionJobName"),
        "sentiment": senti['Sentiment'],
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

    table.put_item(Item=result)

    # 5) Metrics
    if senti['Sentiment'] is "POSITIVE":
        metrics.add_metric(name="positiveSentiment", unit=MetricUnit.Count, value=1)
    elif senti['Sentiment'] is "NEGATIVE":
        metrics.add_metric(name="negativeSentiment", unit=MetricUnit.Count, value=1)
    else:
        metrics.add_metric(name="mixedSentiment", unit=MetricUnit.Count, value=1)

    if output["call_type"] is "personal":
        metrics.add_metric(name="personalCall", unit=MetricUnit.Count, value=1)
    elif output["call_type"] is "business":
        metrics.add_metric(name="businessCall", unit=MetricUnit.Count, value=1)
    else:
        metrics.add_metric(name="unknownCall", unit=MetricUnit.Count, value=1)

    return {"ok": True, "result_key": result_key}
