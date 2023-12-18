variable "vpc_cidr" {
  type        = string
  description = "CIDR range of the AWS VPC the workspace will be deployed in"
  default     = "10.10.0.0/16"
}

variable "region" {
  type        = string
  description = "Region resources and Databricks will be deployed in"
  default     = "us-east-1" # Use us-west-2 or us-east-1 or else PrivateLink won't work
}

variable "databricks_account_id" {
  type        = string
  description = "Databricks account id from accounts console"
}

variable "databricks_account_username" {
  type = string
}

variable "databricks_account_password" {
  type = string # https://learn.hashicorp.com/tutorials/terraform/sensitive-variables?in=terraform/0-14#set-values-with-environment-variables
}

variable "databricks_aws_account_id" {
  type        = string
  description = "Databricks AWS account id. This is unlikely to change ever."
  default     = "414351767826"
}

variable "prefix" {
  type        = string
  description = "Prefix to be attached to every AWS and Databricks resource created for uniqueness"
}

variable "tags" {
  type        = map(any)
  description = "Tags to be applied to all AWS resources"
}

variable "force_destroy" {
  type        = bool
  description = "Whether S3 buckets should be deleted when you run terraform destroy"
  default     = true
}

variable "pl_service_workspace" {
  type        = string
  description = "VPC Endpoint service for the region you're deploying in for the Frontend/workspace"
  default     = "com.amazonaws.vpce.us-west-2.vpce-svc-0129f463fcfbc46c5" # This is for us-west-2
}

variable "pl_service_relay" {
  type        = string
  description = "VPC Endpoint service for the region you're deploying in for the Backend/SCC relay service "
  default     = "com.amazonaws.vpce.us-west-2.vpce-svc-0158114c0c730c3bb" # This is for us-west-2
}

variable "pl_private_dns_enabled" {
  type        = bool
  description = "Whether to enable private DNS for the privatelink VPC Endpoints. Set this to true only after endpoints have been registered"
  default     = false
}