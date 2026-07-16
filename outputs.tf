output "lambda_function_name" {
  description = "Name of the deployed Lambda function"
  value       = aws_lambda_function.fixed_response.function_name
}

output "lambda_function_arn" {
  description = "ARN of the deployed Lambda function"
  value       = aws_lambda_function.fixed_response.arn
}

output "lambda_execution_role_arn" {
  description = "Execution role ARN — must end with /LabRole"
  value       = aws_lambda_function.fixed_response.role
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.config.arn
}

output "secret_name" {
  description = "Name of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.config.name
}

output "invoke_cli_command" {
  description = "CLI command to invoke the Lambda and see the fixed response"
  value       = "aws lambda invoke --function-name ${aws_lambda_function.fixed_response.function_name} --region ${var.aws_region} /tmp/out.json && cat /tmp/out.json"
}
