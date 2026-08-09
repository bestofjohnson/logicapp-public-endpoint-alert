variable "location" {
  description = "Azure region for the Logic App and API connection."
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Resource group where the Logic App will be deployed."
  type        = string
}

variable "logic_app_name" {
  description = "Name of the Consumption Logic App."
  type        = string
}

variable "office365_connection_name" {
  description = "Name of the Office 365 API connection used by the Logic App."
  type        = string
  default     = "office365-public-endpoint-alert"
}

variable "target_management_group_name" {
  description = "Target Azure Management Group name/id that Azure Resource Graph will query."
  type        = string
}

variable "alert_distribution_list" {
  description = "Distribution list that receives public endpoint findings."
  type        = string
}

variable "email_subject" {
  description = "Email subject for the public endpoint alert."
  type        = string
  default     = "Azure Public Endpoint Findings Detected"
}

variable "recurrence_frequency" {
  description = "Recurrence frequency for the Logic App trigger."
  type        = string
  default     = "Day"

  validation {
    condition = contains([
      "Second",
      "Minute",
      "Hour",
      "Day",
      "Week",
      "Month"
    ], var.recurrence_frequency)

    error_message = "recurrence_frequency must be one of: Second, Minute, Hour, Day, Week, Month."
  }
}

variable "recurrence_interval" {
  description = "Recurrence interval. For once daily, use 1."
  type        = number
  default     = 1
}

variable "recurrence_hour" {
  description = "Hour of day when the Logic App should run. Uses Eastern Standard Time in the workflow definition."
  type        = number
  default     = 7
}

variable "recurrence_minute" {
  description = "Minute when the Logic App should run."
  type        = number
  default     = 0
}

variable "tags" {
  description = "Tags to apply to Azure resources."
  type        = map(string)

  default = {
    ManagedBy   = "Terraform"
    Workload    = "PublicEndpointAlerting"
    Environment = "dev"
  }
}
