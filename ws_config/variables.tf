variable "databricks_account_id" {
  type        = string
}

variable "ip_arn" {
  type = string
}

variable "group_b_role_name" {
  type = string
}

variable "group_b_role_arn" {
  type = string
}

variable "group_b_bucket_id" {
  type = string
}

variable "log_arn" {
  type = string
}

variable "log_bucket" {
  type = string
}

variable "log_ip_arn" {
  type = string
}

variable "workspace_id" {
  type = string
}

variable "workspace_url" {
  type = string
}

variable "region" {
  type = string
}

variable "prefix" {
  type = string
}

locals {
  groups=[data.databricks_group.b.id, data.databricks_group.a.id]
}

variable "github_token" {
  type        = string
  description = "Repo token"
  default = ""
}


