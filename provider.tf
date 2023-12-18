terraform {
  required_providers {
    databricks = {
      source = "databricks/databricks"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.15.0"
    }
  }
}

provider "aws" {
    region = var.region
    profile = "aws-sandbox-field-eng_databricks-sandbox-admin"
}

provider "databricks" {
  alias      = "mws"
  host       = "https://accounts.cloud.databricks.com"
  account_id = var.databricks_account_id
  username   = var.databricks_account_username
  password   = var.databricks_account_password
}

provider "databricks" {
  alias    = "created_workspace"
  host     = module.ws_core.workspace_url
  account_id = var.databricks_account_id
  username = var.databricks_account_username
  password = var.databricks_account_password
}