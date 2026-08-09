terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

data "azurerm_subscription" "current" {}

data "azurerm_management_group" "target" {
  name = var.target_management_group_name
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location

  tags = var.tags
}

# ------------------------------------------------------------
# Logic App Consumption Workflow
# ------------------------------------------------------------
resource "azurerm_logic_app_workflow" "arg_public_endpoint_alert" {
  name                = var.logic_app_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  enabled             = true

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# ------------------------------------------------------------
# Assign Reader to Logic App Managed Identity at Management Group
# ------------------------------------------------------------
resource "azurerm_role_assignment" "logicapp_reader_mg" {
  scope                = data.azurerm_management_group.target.id
  role_definition_name = "Reader"
  principal_id         = azurerm_logic_app_workflow.arg_public_endpoint_alert.identity[0].principal_id

  # Useful when assigning permissions to a newly created managed identity
  skip_service_principal_aad_check = true
}

# ------------------------------------------------------------
# Deploy Office 365 API Connection and Logic App Definition
# ------------------------------------------------------------
resource "azurerm_resource_group_template_deployment" "logicapp_definition" {
  name                = "deploy-${var.logic_app_name}-definition"
  resource_group_name = azurerm_resource_group.rg.name
  deployment_mode     = "Incremental"

  depends_on = [
    azurerm_logic_app_workflow.arg_public_endpoint_alert,
    azurerm_role_assignment.logicapp_reader_mg
  ]

  parameters_content = jsonencode({
    logicAppName = {
      value = var.logic_app_name
    }

    location = {
      value = var.location
    }

    office365ConnectionName = {
      value = var.office365_connection_name
    }

    emailTo = {
      value = var.alert_distribution_list
    }

    emailSubject = {
      value = var.email_subject
    }

    targetManagementGroupName = {
      value = var.target_management_group_name
    }

    recurrenceFrequency = {
      value = var.recurrence_frequency
    }

    recurrenceInterval = {
      value = var.recurrence_interval
    }

    recurrenceHour = {
      value = var.recurrence_hour
    }

    recurrenceMinute = {
      value = var.recurrence_minute
    }

    resourceGraphQuery = {
      value = local.resource_graph_query
    }
  })

  template_content = jsonencode({
    "$schema"      = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
    contentVersion = "1.0.0.0"

    parameters = {
      logicAppName = {
        type = "string"
      }

      location = {
        type = "string"
      }

      office365ConnectionName = {
        type = "string"
      }

      emailTo = {
        type = "string"
      }

      emailSubject = {
        type = "string"
      }

      targetManagementGroupName = {
        type = "string"
      }

      recurrenceFrequency = {
        type = "string"
      }

      recurrenceInterval = {
        type = "int"
      }

      recurrenceHour = {
        type = "int"
      }

      recurrenceMinute = {
        type = "int"
      }

      resourceGraphQuery = {
        type = "string"
      }
    }

    resources = [
      {
        type       = "Microsoft.Web/connections"
        apiVersion = "2016-06-01"
        name       = "[parameters('office365ConnectionName')]"
        location   = "[parameters('location')]"

        properties = {
          displayName = "[parameters('office365ConnectionName')]"

          api = {
            id = "[subscriptionResourceId('Microsoft.Web/locations/managedApis', parameters('location'), 'office365')]"
          }
        }
      },
      {
        type       = "Microsoft.Logic/workflows"
        apiVersion = "2019-05-01"
        name       = "[parameters('logicAppName')]"
        location   = "[parameters('location')]"

        identity = {
          type = "SystemAssigned"
        }

        dependsOn = [
          "[resourceId('Microsoft.Web/connections', parameters('office365ConnectionName'))]"
        ]

        properties = {
          state = "Enabled"

          parameters = {
            "$connections" = {
              value = {
                office365 = {
                  connectionId   = "[resourceId('Microsoft.Web/connections', parameters('office365ConnectionName'))]"
                  connectionName = "[parameters('office365ConnectionName')]"
                  id             = "[subscriptionResourceId('Microsoft.Web/locations/managedApis', parameters('location'), 'office365')]"
                }
              }
            }
          }

          definition = {
            "$schema"        = "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#"
            contentVersion   = "1.0.0.0"

            parameters = {
              "$connections" = {
                type         = "Object"
                defaultValue = {}
              }
            }

            triggers = {
              Daily_Recurrence = {
                type = "Recurrence"

                recurrence = {
                  frequency = "[parameters('recurrenceFrequency')]"
                  interval  = "[parameters('recurrenceInterval')]"

                  schedule = {
                    hours   = [
                      "[parameters('recurrenceHour')]"
                    ]

                    minutes = [
                      "[parameters('recurrenceMinute')]"
                    ]
                  }

                  timeZone = "Eastern Standard Time"
                }
              }
            }

            actions = {
              HTTP_Query_Azure_Resource_Graph = {
                type = "Http"

                inputs = {
                  method = "POST"
                  uri    = "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2022-10-01"

                  authentication = {
                    type     = "ManagedServiceIdentity"
                    audience = "https://management.azure.com/"
                  }

                  headers = {
                    "Content-Type" = "application/json"
                  }

                  body = {
                    managementGroups = [
                      "[parameters('targetManagementGroupName')]"
                    ]

                    query = "[parameters('resourceGraphQuery')]"

                    options = {
                      resultFormat = "objectArray"
                    }
                  }
                }

                runAfter = {}
              }

              Check_If_Findings_Exist = {
                type = "If"

                expression = {
                  greater = [
                    "@coalesce(body('HTTP_Query_Azure_Resource_Graph')?['totalRecords'], 0)",
                    0
                  ]
                }

                actions = {
                  Create_HTML_Table = {
                    type = "Table"

                    inputs = {
                      from   = "@body('HTTP_Query_Azure_Resource_Graph')?['data']"
                      format = "HTML"
                    }
                  }

                  Send_Email_To_Distribution_List = {
                    type = "ApiConnection"

                    inputs = {
                      host = {
                        connection = {
                          name = "@parameters('$connections')['office365']['connectionId']"
                        }
                      }

                      method = "post"

                      path = "/v2/Mail"

                      body = {
                        To      = "[parameters('emailTo')]"
                        Subject = "[parameters('emailSubject')]"

                        Body = "@concat('<p>Hello Team,</p><p>The daily Azure Resource Graph scan found resources with public network access enabled, public IP resources, or Azure Monitor public access not fully disabled.</p><p>Total findings: ', string(body('HTTP_Query_Azure_Resource_Graph')?['totalRecords']), '</p>', body('Create_HTML_Table'), '<p>Regards,<br/>Cloud Engineering Automation</p>')"

                        Importance = "High"
                      }
                    }

                    runAfter = {
                      Create_HTML_Table = [
                        "Succeeded"
                      ]
                    }
                  }

                  # ------------------------------------------------------------
                  # Future ServiceNow Option
                  # ------------------------------------------------------------
                  # Replace or extend the email action with an HTTP action similar
                  # to the example below after ServiceNow endpoint and auth method
                  # are confirmed.
                  #
                  # Create_ServiceNow_Incident = {
                  #   type = "Http"
                  #   inputs = {
                  #     method = "POST"
                  #     uri    = "https://your-instance.service-now.com/api/now/table/incident"
                  #     headers = {
                  #       "Content-Type" = "application/json"
                  #     }
                  #     body = {
                  #       short_description = "Azure public endpoint findings detected"
                  #       description       = "@string(body('HTTP_Query_Azure_Resource_Graph')?['data'])"
                  #       urgency           = "2"
                  #       impact            = "2"
                  #     }
                  #   }
                  # }
                }

                else = {
                  actions = {
                    No_Findings = {
                      type = "Compose"

                      inputs = "No public endpoint findings were returned by Azure Resource Graph."
                    }
                  }
                }

                runAfter = {
                  HTTP_Query_Azure_Resource_Graph = [
                    "Succeeded"
                  ]
                }
              }
            }

            outputs = {}
          }
        }
      }
    ]

    outputs = {
      office365ConnectionId = {
        type  = "string"
        value = "[resourceId('Microsoft.Web/connections', parameters('office365ConnectionName'))]"
      }
    }
  })
}

# ------------------------------------------------------------
# Azure Resource Graph Query
# ------------------------------------------------------------
locals {
  resource_graph_query = <<-KQL
let PublicNetworkAccessResources =
    Resources
    | where type in~ (
        "microsoft.storage/storageaccounts",
        "microsoft.keyvault/vaults",
        "microsoft.sql/servers",
        "microsoft.documentdb/databaseaccounts",
        "microsoft.web/sites",
        "microsoft.containerregistry/registries",
        "microsoft.cognitiveservices/accounts",
        "microsoft.search/searchservices",
        "microsoft.appconfiguration/configurationstores",
        "microsoft.eventhub/namespaces",
        "microsoft.servicebus/namespaces",
        "microsoft.cache/redis",
        "microsoft.dbformysql/flexibleservers",
        "microsoft.dbforpostgresql/flexibleservers",
        "microsoft.machinelearningservices/workspaces",
        "microsoft.synapse/workspaces"
    )
    | extend PublicNetworkAccess = tostring(properties.publicNetworkAccess)
    | where PublicNetworkAccess =~ "Enabled"
        or PublicNetworkAccess =~ "SecuredByPerimeter"
        or PublicNetworkAccess == ""
    | project
        subscriptionId,
        resourceGroup,
        name,
        type,
        location,
        finding = "Public network access enabled or not explicitly disabled",
        publicNetworkAccess = PublicNetworkAccess,
        resourceId = id;

let AzureMonitorResources =
    Resources
    | where type in~ (
        "microsoft.operationalinsights/workspaces",
        "microsoft.insights/components"
    )
    | extend
        QueryAccess = tostring(properties.publicNetworkAccessForQuery),
        IngestionAccess = tostring(properties.publicNetworkAccessForIngestion)
    | where QueryAccess !~ "Disabled"
        or IngestionAccess !~ "Disabled"
    | project
        subscriptionId,
        resourceGroup,
        name,
        type,
        location,
        finding = strcat(
            "Azure Monitor public access: Query=",
            QueryAccess,
            ", Ingestion=",
            IngestionAccess
        ),
        publicNetworkAccess = strcat(
            "Query=",
            QueryAccess,
            "; Ingestion=",
            IngestionAccess
        ),
        resourceId = id;

let PublicIPResources =
    Resources
    | where type =~ "microsoft.network/publicipaddresses"
    | extend
        IpAddress = tostring(properties.ipAddress),
        AllocationMethod = tostring(properties.publicIPAllocationMethod)
    | project
        subscriptionId,
        resourceGroup,
        name,
        type,
        location,
        finding = "Public IP address resource exists",
        publicNetworkAccess = strcat(
            "IP=",
            IpAddress,
            "; Allocation=",
            AllocationMethod
        ),
        resourceId = id;

union
    PublicNetworkAccessResources,
    AzureMonitorResources,
    PublicIPResources
| order by subscriptionId asc, type asc, name asc
KQL
}
