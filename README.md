# AWS Text-to-Speech Converter using Terraform, AWS Lambda, API Gateway, and S3

## Overview
This project automates infrastructure provisioning using Terraform and deploys an AWS Lambda function that converts text to speech using AWS Polly. The generated audio is stored in an S3 bucket, and the Lambda function is exposed via API Gateway.

## Tech Stack
- **Terraform**: Infrastructure as Code (IaC)
- **AWS Lambda**: Serverless function execution
- **AWS Polly**: Text-to-Speech conversion
- **Amazon S3**: Storage for generated audio files
- **API Gateway**: Exposes Lambda as an HTTP endpoint

---

## Infrastructure Setup with Terraform

### 1. **Terraform Configuration File (`main.tf`)**
This file initializes Terraform and sets up the AWS provider.

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "aws" {
  region = "us-east-1"  # Change as needed
}
```

---

### 2. **IAM Role for Lambda (`iam.tf`)**
Defines an IAM role that allows Lambda to execute and interact with AWS resources.

```hcl
resource "aws_iam_role" "lambda_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}



resource "aws_iam_policy" "lambda_polly_s3_access" {
  name = "LambdaPollyS3AccessPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${aws_s3_bucket.polly_audio_bucket.arn}",
          "${aws_s3_bucket.polly_audio_bucket.arn}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["polly:SynthesizeSpeech"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.text_to_speech_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.text_to_speech_api.execution_arn}/*/*"
}



resource "aws_iam_role_policy_attachment" "lambda_polly_s3" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_polly_s3_access.arn
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
```

---

### 3. **S3 Bucket for Storing Audio Files (`s3.tf`)**
Creates an S3 bucket to store generated audio files.

```hcl
resource "aws_s3_bucket" "polly_audio_bucket" {
  bucket = "my-tts-audio-bucket-123456"

  tags = {
    Name        = "TextToSpeechBucket"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_public_access_block" "polly_audio_bucket_access" {
  bucket = aws_s3_bucket.polly_audio_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

```

---

### 4. **Lambda Function Deployment (`lambda.tf`)**
Deploys the Lambda function for text-to-speech conversion.

```hcl
resource "aws_lambda_function" "text_to_speech_lambda" {
  function_name    = "TextToSpeechLambda"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.lambda_handler"
  runtime          = "python3.9"
  filename         = "lambda_function.zip"
  source_code_hash = filebase64sha256("lambda_function.zip")

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.polly_audio_bucket.id
    }
  }

  depends_on = [aws_iam_role.lambda_role]
}

```
The `lambda_function.zip` file contains the Python script (`index.py`) for AWS Lambda.

---

### 5. **API Gateway Integration (`api_gateway.tf`)**
Exposes the Lambda function via API Gateway.

```hcl
resource "aws_api_gateway_rest_api" "text_to_speech_api" {
  name        = "TextToSpeechAPI"
  description = "API Gateway for Text to Speech Lambda"
}

resource "aws_api_gateway_resource" "text_to_speech_resource" {
  rest_api_id = aws_api_gateway_rest_api.text_to_speech_api.id
  parent_id   = aws_api_gateway_rest_api.text_to_speech_api.root_resource_id
  path_part   = "convert"
}

resource "aws_api_gateway_method" "post_method" {
  rest_api_id   = aws_api_gateway_rest_api.text_to_speech_api.id
  resource_id   = aws_api_gateway_resource.text_to_speech_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.text_to_speech_api.id
  resource_id = aws_api_gateway_resource.text_to_speech_resource.id
  http_method = aws_api_gateway_method.post_method.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.text_to_speech_lambda.invoke_arn
}

resource "aws_api_gateway_deployment" "deployment" {
  depends_on  = [aws_api_gateway_integration.lambda_integration]
  rest_api_id = aws_api_gateway_rest_api.text_to_speech_api.id
  stage_name  = "dev"
}

```

---


## Lambda Function Code (`index.py`)

```python
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

```

---

## Deploying the Infrastructure

### Step 1: Initialize Terraform
```sh
terraform init
```

### Step 2: Format and Validate Terraform Code
```sh
terraform fmt
terraform validate
```

### Step 3: Deploy Infrastructure
```sh
terraform apply -auto-approve
```

---

## Testing the API

### Invoke Lambda Directly
```sh
aws lambda invoke \
    --function-name TextToSpeechLambda \
    --cli-binary-format raw-in-base64-out \
    --payload '{ "text": "Hello AWS!" }' \
    response.json

```

### Test via API Gateway (Using cURL)
```sh
curl -X POST "https://your-api-id.execute-api.us-east-1.amazonaws.com/dev/convert" \
     -H "Content-Type: application/json" \
     -d '{ "text": "Hello from API Gateway!" }'
```

### Test via Postman
- **Method**: POST
- **URL**: `https://your-api-id.execute-api.us-east-1.amazonaws.com/dev/convert`
- **Headers**: `Content-Type: application/json`
- **Body**:
```json
{
    "text": "Hello AWS Polly!"
}
```

---

## Cleanup
To remove all AWS resources:
```sh
terraform destroy -auto-approve
```

---

## Conclusion
This project demonstrates how to automate AWS infrastructure provisioning using Terraform and deploy a serverless text-to-speech application using AWS Lambda, Polly, S3, and API Gateway. 🚀

