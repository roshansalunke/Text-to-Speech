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

