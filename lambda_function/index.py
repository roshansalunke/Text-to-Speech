import json
import boto3
import os
import uuid

s3 = boto3.client("s3")
polly = boto3.client("polly")

BUCKET_NAME = os.environ["BUCKET_NAME"]

def lambda_handler(event, context):
    #text = event.get("text", "Hello, this is a test from AWS Polly!")
    body = json.loads(event["body"])  # Extract text
    text = body.get("text", "Default text")
    # Convert text to speech
    response = polly.synthesize_speech(
        Text=text, OutputFormat="mp3", VoiceId="Joanna"
    )

    # Generate a unique filename
    file_name = f"audio-{uuid.uuid4()}.mp3"
    file_path = f"/tmp/{file_name}"

    # Save the audio stream to a file
    with open(file_path, "wb") as f:
        f.write(response["AudioStream"].read())

    # Upload to S3
    s3.upload_file(file_path, BUCKET_NAME, file_name)

    return {
        "statusCode": 200,
        "body": json.dumps(
            {"message": "Audio file generated", "file_url": f"s3://{BUCKET_NAME}/{file_name}"}
        ),
    }

