/*Databricks workspace initialization*/
module "ws_core" {
  source = ".//ws_core"
    providers = {
    databricks.mws = databricks.mws,
    aws = aws
  }
  databricks_account_username = var.databricks_account_username
  databricks_account_password = var.databricks_account_password
  databricks_account_id = var.databricks_account_id
  tags = var.tags
  prefix = var.prefix
}


/*Databricks workspace configuration*/
module "ws_config" {
  source = ".//ws_config"
    providers = {
    databricks.mws = databricks.mws
    databricks.created_workspace = databricks.created_workspace
  }
  databricks_account_id = var.databricks_account_id
  region = var.region
  prefix = var.prefix
  ip_arn = module.ws_core.ip_arn
  log_arn = module.ws_core.log_arn
  log_bucket = module.ws_core.log_bucket
  log_ip_arn = module.ws_core.log_ip_arn
  group_b_role_name = module.ws_core.group_b_role_name
  group_b_role_arn = module.ws_core.group_b_role_arn
  group_b_bucket_id = module.ws_core.group_b_bucket_id
  workspace_id =  split("/", module.ws_core.workspace_id)[1]
  workspace_url = module.ws_core.workspace_url
}
