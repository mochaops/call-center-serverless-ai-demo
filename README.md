aws polly synthesize-speech \
  --voice-id Miguel \
  --output-format mp3 \
  --text "Hola, solo quiero quejarme mucho de los repartidores que dejaron mi paquete afuera de mi domicilio y no preguntaron por mi, muy poco profesionales." \
  prueba-miguel.mp3

aws polly synthesize-speech \
  --voice-id Enrique \
  --output-format mp3 \
  --text "Este es un mensaje de prueba. Estoy llamando a la línea de soporte. Por favor grabe este mensaje." \
  prueba-enrique.mp3


{
  "Records": [
    {
      "eventVersion": "2.1",
      "eventSource": "aws:s3",
      "awsRegion": "us-east-1",
      "eventTime": "2025-11-11T23:50:00.000Z",
      "eventName": "ObjectCreated:Put",
      "userIdentity": {
        "principalId": "AWS:EXAMPLE"
      },
      "requestParameters": {
        "sourceIPAddress": "10.0.0.1"
      },
      "responseElements": {
        "x-amz-request-id": "ABCDEFG123456",
        "x-amz-id-2": "XYZexample123/abcdefghijklmn"
      },
      "s3": {
        "s3SchemaVersion": "1.0",
        "configurationId": "lambda-trigger",
        "bucket": {
          "name": "ia-demo-connect-recordings-d1a2db35",
          "ownerIdentity": {
            "principalId": "EXAMPLE"
          },
          "arn": "arn:aws:s3:::ia-demo-connect-recordings-d1a2db35"
        },
        "object": {
          "key": "record_a.m4a",
          "size": 24960,
          "eTag": "7eeb2f5769a447f8a475b8c881ca32f7",
          "sequencer": "00123456789ABCDEFFEDCBA987654321"
        }
      }
    }
  ]
}


{
  "version": "0",
  "id": "11111111-2222-3333-4444-555555555555",
  "detail-type": "Transcribe Job State Change",
  "source": "aws.transcribe",
  "account": "TU_ACCOUNT_ID",
  "time": "2025-11-11T23:59:00Z",
  "region": "us-east-1",
  "resources": [],
  "detail": {
    "TranscriptionJobName": "job-1234-uuid",
    "TranscriptionJobStatus": "COMPLETED",
    "OutputLocation": "s3://TU_OUTPUTS_BUCKET/job-1234-uuid.json"
  }
}
