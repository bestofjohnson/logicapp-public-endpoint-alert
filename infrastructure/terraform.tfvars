location = "eastus"

resource_group_name = "rg-logicapp-public-endpoint-alert-prd"

logic_app_name = "la-public-endpoint-alert-prd"

office365_connection_name = "office365-public-endpoint-alert-prd"

target_management_group_name = "your-management-group-name"

alert_distribution_list = "your-distribution-list@contoso.com"

email_subject = "Azure Public Endpoint Findings Detected"

recurrence_frequency = "Day"
recurrence_interval  = 1
recurrence_hour      = 7
recurrence_minute    = 0

tags = {
  ManagedBy    = "Terraform"
  Workload     = "PublicEndpointAlerting"
  Environment  = "prd"
  Owner        = "CloudEngineering"
  AlertPurpose = "PublicEndpointDetection"
}
