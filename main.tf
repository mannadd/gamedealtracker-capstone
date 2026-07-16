###############################################################################
# Provider
###############################################################################
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

###############################################################################
# Data source — existing LabRole (no iam:CreateRole needed)
###############################################################################
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

###############################################################################
# Package the Lambda source into a zip
###############################################################################
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/.terraform/lambda_package.zip"
}

###############################################################################
# Lambda function
###############################################################################
resource "aws_lambda_function" "fixed_response" {
  function_name    = "${var.project_name}-fixed-response"
  description      = "Session 3 capstone — returns a fixed JSON response; no external API call yet."
  role             = data.aws_iam_role.lab_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 10

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  environment {
    variables = {
      # Passes only the *name* of the secret — never its value.
      # The value must be set out-of-band (see README for the CLI command).
      SECRET_NAME = var.secret_name
      TABLE_NAME  = var.dynamodb_table_name
    }
  }

  tags = {
    Project = var.project_name
    Session = "3"
  }
}

###############################################################################
# Secrets Manager — secret shell only
# Value MUST be set out-of-band:
#   aws secretsmanager put-secret-value \
#       --secret-id session3/config \
#       --secret-string '{"api_key":"<your-value>"}' \
#       --region us-east-1
###############################################################################
resource "aws_secretsmanager_secret" "config" {
  name                    = var.secret_name
  description             = "Session 3 config. Set the value via CLI/console — never in code or Terraform vars."
  recovery_window_in_days = 0 # allow immediate deletion in the lab environment

  tags = {
    Project = var.project_name
    Session = "3"
  }
}

##############################################################################
# API Gateway HTTP API - public front door for the Lambda
##############################################################################
resource "aws_apigatewayv2_api" "gamedeal_api" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.gamedeal_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.fixed_response.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_deals" {
  api_id    = aws_apigatewayv2_api.gamedeal_api.id
  route_key = "GET /deals"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.gamedeal_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fixed_response.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.gamedeal_api.execution_arn}/*/*"
}

output "api_endpoint" {
  description = "Public HTTPS endpoint for the /deals route"
  value       = "${aws_apigatewayv2_stage.default.invoke_url}/deals"
}

##############################################################################
# SQS Dead-Letter Queue — captures failed async Lambda invocations
##############################################################################
resource "aws_sqs_queue" "lambda_dlq" {
  name = "${var.project_name}-lambda-dlq"

  tags = {
    Project = var.project_name
    Session = "4"
  }
}
