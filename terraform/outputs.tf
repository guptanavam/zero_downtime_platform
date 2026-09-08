output "configured_region" {
  description = "Active AWS deployment region"
  value       = var.aws_region
}

output "deployment_environment" {
  description = "Active deployment environment"
  value       = var.environment
}