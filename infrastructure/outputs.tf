output "logic_app_name" {
  value = azurerm_logic_app_workflow.arg_public_endpoint_alert.name
}

output "logic_app_id" {
  value = azurerm_logic_app_workflow.arg_public_endpoint_alert.id
}

output "logic_app_identity_principal_id" {
  value = azurerm_logic_app_workflow.arg_public_endpoint_alert.identity[0].principal_id
}

output "target_management_group_id" {
  value = data.azurerm_management_group.target.id
}

output "reader_role_assignment_id" {
  value = azurerm_role_assignment.logicapp_reader_mg.id
}

output "office365_connection_name" {
  value = var.office365_connection_name
}

output "alert_distribution_list" {
  value = var.alert_distribution_list
}
