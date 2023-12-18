databricks_account_id       = ""
databricks_account_username = ""
databricks_account_password = ""
vpc_cidr                    = "10.10.0.0/16"
prefix                      = "[your name]-sandbox"
tags = {
  Owner       = ""
  Environment = ""
  Budget      = ""
}
force_destroy          = true #destroy buckets when destroying
pl_service_workspace   = "com.amazonaws.vpce.us-west-2.vpce-svc-0129f463fcfbc46c5"
pl_service_relay       = "com.amazonaws.vpce.us-west-2.vpce-svc-0158114c0c730c3bb"
pl_private_dns_enabled = false # Set to true after endpoints have been registered