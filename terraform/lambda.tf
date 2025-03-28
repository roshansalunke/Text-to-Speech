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

