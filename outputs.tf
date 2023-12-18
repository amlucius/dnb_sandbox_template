output "workspace_details" {
  value = [module.ws_core.workspace_url, split("/", module.ws_core.workspace_id)[1], module.ws_core.workspace_region]
}