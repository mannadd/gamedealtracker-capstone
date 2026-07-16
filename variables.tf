variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used to prefix all resource names"
  type        = string
  default     = "session3"
}

variable "secret_name" {
  description = "Name of the Secrets Manager secret. The *value* is set out-of-band; never pass it here."
  type        = string
  default     = "session3/config"
}

variable "dynamodb_table_name" {
  description = "Name of the existing DynamoDB table to write deals into"
  type        = string
  default     = "gamedeal-tracker-deals"
}
