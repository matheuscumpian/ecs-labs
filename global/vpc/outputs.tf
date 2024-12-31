output "vpc_id" {
  value       = aws_ssm_parameter.vpc_id.value
  description = "value of the VPC ID"
}

output "private_subnet_ids" {
  value       = aws_ssm_parameter.private_subnet_ids.value
  description = "value of the private subnet IDs"
}

output "public_subnet_ids" {
  value       = aws_ssm_parameter.public_subnet_ids.value
  description = "value of the public subnet IDs"
}

output "databases_subnet_ids" {
  value       = aws_ssm_parameter.databases_subnet_ids.value
  description = "value of the databases subnet IDs"
}

output "nat_gateway_id" {
  value       = aws_ssm_parameter.nat_gateway_id.value
  description = "value of the NAT Gateway ID"
}

output "internet_gateway_id" {
  value       = aws_internet_gateway.main.id
  description = "value of the Internet Gateway ID"
}

output "vpc_cidr" {
  value       = var.vpc_cidr
  description = "value of the VPC CIDR"
}

