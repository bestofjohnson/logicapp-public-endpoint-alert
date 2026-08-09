locals {
  management_group_scope = "/providers/Microsoft.Management/managementGroups/${var.management_group_id}"

  resource_graph_query = <<KQL
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
