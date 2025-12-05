import time

import os, json, urllib.parse, boto3, uuid

s3 = boto3.client("s3")
transcribe = boto3.client("transcribe")

REGION = os.environ.get("REGION", "us-east-1")
RECORDINGS_BUCKET = os.environ["RECORDINGS_BUCKET"]
OUTPUTS_BUCKET = os.environ["OUTPUTS_BUCKET"]

def lambda_handler(event, context):
    # Evento S3 ObjectCreated
    bucket = event['detail']['bucket']['name']
    key    = event['detail']['object']['key']
    if not key.lower().endswith((".wav",".mp3",".mp4",".m4a",".flac",".ogg",".webm")):
        print(f"File {key} is not a supported audio format, raising exception")
        raise ValueError(f"File {key} is not a supported audio format")

    job_name = f"job-{uuid.uuid4()}"
    media_uri = f"s3://{bucket}/{key}"

    transcribe.start_transcription_job(
        TranscriptionJobName=job_name,
        IdentifyLanguage=True,
        LanguageOptions=["es-US","es-ES"],
        Media={"MediaFileUri": media_uri},
        OutputBucketName=OUTPUTS_BUCKET,
        Settings={"ShowSpeakerLabels": True, "MaxSpeakerLabels": 2}
    )
    # Wait for transcription job to complete
    max_attempts = 120
    delay = 5
    attempt = 0

    while attempt < max_attempts:
        response = transcribe.get_transcription_job(TranscriptionJobName=job_name)
        status = response['TranscriptionJob']['TranscriptionJobStatus']

        if status == 'COMPLETED':
            break
        elif status == 'FAILED':
            raise Exception(f"Transcription job {job_name} failed")

        # Exponential backoff
        wait_time = delay * (2 ** min(attempt, 6))  # Cap at 2^6 to avoid too long waits
        time.sleep(wait_time)
        attempt += 1

    if attempt >= max_attempts:
        raise Exception(f"Transcription job {job_name} timed out after {max_attempts} attempts")

    return {
            "ok": True,
            "TranscriptionJobName": job_name
            }
