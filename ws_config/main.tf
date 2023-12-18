#create rootless UC metastore
resource "databricks_metastore" "this" {
  provider      =  databricks.mws
  name          = "${var.prefix}-metastore"
  owner         = "dnb_admins"
  region        = var.region
  force_destroy = true
}

#assign UC metastore to workspace
resource "databricks_metastore_assignment" "this" {
  provider     = databricks.mws
  metastore_id = databricks_metastore.this.id
  workspace_id = var.workspace_id
  }

#create main catalog
resource "databricks_catalog" "main" {
  provider = databricks.created_workspace
  metastore_id = databricks_metastore.this.id
  name         = "main"
  comment      = "this catalog is managed by terraform"
  storage_root = "s3://${var.group_b_bucket_id}"
  force_destroy = true
}

#create default schema within main catalog
resource "databricks_schema" "default" {
  provider = databricks.created_workspace
  catalog_name = databricks_catalog.main.id
  name         = "default"
  comment      = "this schema is managed by terraform"
}

#Add Group A to workspace from account
#should already exist in account, need metastore assigned before you can do this
data "databricks_group" "a" {
   display_name = "Group A"
   provider     = databricks.mws
 }

 resource "databricks_mws_permission_assignment" "a" {
  provider             = databricks.mws
  workspace_id         = var.workspace_id
  principal_id         = data.databricks_group.a.id
  permissions          = ["USER"]
}

resource "databricks_entitlements" "a" {
  provider                   = databricks.created_workspace
  group_id                   = data.databricks_group.a.id
  workspace_access           = true
  allow_cluster_create       = true
  databricks_sql_access      = true
}

#Add Group B to workspace from account
data "databricks_group" "b" {
   display_name = "Group B"
   provider     = databricks.mws
 }

 resource "databricks_mws_permission_assignment" "b" {
  provider             = databricks.mws
  workspace_id         = var.workspace_id
  principal_id         = data.databricks_group.b.id
  permissions          = ["USER"]
}

resource "databricks_entitlements" "b" {
  provider                   = databricks.created_workspace
  group_id                   = data.databricks_group.b.id
  workspace_access           = true
  allow_cluster_create       = true
  databricks_sql_access      = true
}

#Add Group C to workspace from account
data "databricks_group" "c" {
   display_name = "Group C"
   provider     = databricks.mws
 }

 resource "databricks_mws_permission_assignment" "c" {
  provider             = databricks.mws
  workspace_id         = var.workspace_id
  principal_id         = data.databricks_group.c.id
  permissions          = ["USER"]
}

resource "databricks_entitlements" "c" {
  provider                   = databricks.created_workspace
  group_id                   = data.databricks_group.c.id
  workspace_access           = true
  allow_cluster_create       = true
  databricks_sql_access      = false
}

##########################################################
#add group B instance profile to databricks workspace
resource "databricks_instance_profile" "groupb-profile" {
  provider             = databricks.created_workspace
  instance_profile_arn = var.ip_arn
}

#grant permissions on Group B instance profile in workspace
resource "databricks_group_role" "group_b_instance_profile"{
  provider            = databricks.created_workspace
  role                = databricks_instance_profile.groupb-profile.id
  for_each            = toset(local.groups)
  group_id            = each.key
}

#########################################################
#add UC storage credential
resource "databricks_storage_credential" "external" {
  provider            = databricks.created_workspace
  name                = var.group_b_role_name
  aws_iam_role {
    role_arn = var.group_b_role_arn
  }
  comment = "Managed by TF"
}

#grant access on the storage crednetial
resource "databricks_grants" "external_creds" {
  provider           = databricks.created_workspace
  storage_credential = databricks_storage_credential.external.id
  grant {
    principal  = "andrew.lucius@databricks.com"
    privileges = ["CREATE_TABLE", "READ_FILES", "WRITE_FILES"]
  }
}

#add UC external location
resource "databricks_external_location" "some" {
  provider        = databricks.created_workspace
  name            = "groupb"
  url             = "s3://${var.group_b_bucket_id}"
  credential_name = databricks_storage_credential.external.id
  comment         = "Managed by TF"
}

#grant access on the external location
resource "databricks_grants" "some" {
  provider            = databricks.created_workspace
  external_location   = databricks_external_location.some.id
  grant {
    principal  = "andrew.lucius@databricks.com"
    privileges = ["CREATE_TABLE", "READ_FILES", "WRITE_FILES"]
  }
}


/*Audit log resources for workspace*/
#add audit log resources to the workspace
resource "databricks_mws_credentials" "log_writer" {
  provider         = databricks.mws
  account_id       = var.databricks_account_id
  credentials_name = "${var.prefix}-logdelivery-credential"
  role_arn         = var.log_arn
}

resource "databricks_mws_storage_configurations" "log_bucket" {
  provider                   = databricks.mws
  account_id                 = var.databricks_account_id
  storage_configuration_name = "${var.prefix}-logdelivery-bucket"
  bucket_name                = var.log_bucket
}

resource "databricks_mws_log_delivery" "usage_logs" {
  provider                 = databricks.mws
  account_id               = var.databricks_account_id
  credentials_id           = databricks_mws_credentials.log_writer.credentials_id
  storage_configuration_id = databricks_mws_storage_configurations.log_bucket.storage_configuration_id
  delivery_path_prefix     = "billable-usage"
  config_name              = "Usage Logs"
  log_type                 = "BILLABLE_USAGE"
  output_format            = "CSV"
}

resource "databricks_mws_log_delivery" "audit_logs" {
  provider                 = databricks.mws
  account_id               = var.databricks_account_id
  credentials_id           = databricks_mws_credentials.log_writer.credentials_id
  storage_configuration_id = databricks_mws_storage_configurations.log_bucket.storage_configuration_id
  delivery_path_prefix     = "audit-logs"
  config_name              = "Audit Logs"
  log_type                 = "AUDIT_LOGS"
  output_format            = "JSON"
}

#add logs instance profile to databricks workspace
resource "databricks_instance_profile" "logs-profile" {
  provider             = databricks.created_workspace
  instance_profile_arn = var.log_ip_arn
}

///////////////*addtional workspace resource*///////////////////////
#add databricks_demos personal github
resource "databricks_git_credential" "ado" {
  provider              = databricks.created_workspace
  git_username          = "amlucius"
  git_provider          = "gitHub"
  personal_access_token = var.github_token
}

resource "databricks_repo" "nutter_in_home" {
  provider            = databricks.created_workspace
  url = "https://github.com/amlucius/databricks_demos"
}

/*Create clusters*/
data "databricks_node_type" "smallest" {
  local_disk = true
}

data "databricks_spark_version" "latest_lts" {
  provider = databricks.created_workspace
  depends_on = [
    var.workspace_url
]
  long_term_support = true
}

#UC Cluster
resource "databricks_cluster" "uc_shared" {
  provider = databricks.created_workspace
  cluster_name            = "UC"
  spark_version           = data.databricks_spark_version.latest_lts.id
  node_type_id            = data.databricks_node_type.smallest.id
  autotermination_minutes = 60
  data_security_mode      = "USER_ISOLATION"
    autoscale {
    min_workers = 1
    max_workers = 2
  }
}

#IP cluster
resource "databricks_cluster" "single_node_ip" {
  provider = databricks.created_workspace
  cluster_name            = "IP"
  spark_version           = data.databricks_spark_version.latest_lts.id
  node_type_id            = data.databricks_node_type.smallest.id
  autotermination_minutes = 60
  aws_attributes {
    instance_profile_arn = var.ip_arn
  }

  spark_conf = {
    # Single-node
    "spark.databricks.cluster.profile" : "singleNode"
    "spark.master" : "local[*]"
  }

  custom_tags = {
    "ResourceClass" = "SingleNode"
  }
}

#Logs IP cluster
resource "databricks_cluster" "single_node_logs" {
  provider = databricks.created_workspace
  cluster_name            = "IP Logs"
  spark_version           = data.databricks_spark_version.latest_lts.id
  node_type_id            = data.databricks_node_type.smallest.id
  autotermination_minutes = 60
  aws_attributes {
    instance_profile_arn = var.log_ip_arn
  }

  spark_conf = {
    # Single-node
    "spark.databricks.cluster.profile" : "singleNode"
    "spark.master" : "local[*]"
  }

  custom_tags = {
    "ResourceClass" = "SingleNode"
  }
}


variable "spark_assume_role_config" {
  type = bool
  default = false
}

#test cluster policy
resource "databricks_cluster_policy" "test" {
  provider = databricks.created_workspace
  name="test"
  definition = jsonencode(
    merge({
    # tags
    "custom_tags.Team" : {
      "type" : "fixed",
      "value" : "test"
    },
    "custom_tags.Cloud" : {
      "type" : "fixed",
      "value" : "aws"
    }},
    coalesce(var.spark_assume_role_config ? {
    "spark_conf.spark.hadoop.fs.s3a.assumed.role.arn" : {
      "type" : "fixed",
      "value" : "arn:aws:iam::003576902480:role/ttd_cluster_compute_adhoc"
    },
    "spark_conf.spark.hadoop.fs.s3a.aws.credentials.provider" : {
      "type" : "fixed",
      "value" : "org.apache.hadoop.fs.s3a.auth.AssumedRoleCredentialProvider"
  }
  }: null, {})))
}
