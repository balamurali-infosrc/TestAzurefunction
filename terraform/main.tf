variable "location" {
  type    = string
  default = "South India"
}

variable "rg_name" {
  type    = string
  default = "demo-func-rg"
}

variable "function_name" {
  type    = string
  default = "demo-func-app"
}
# Generate a short random suffix to ensure global uniqueness for the storage account name
resource "random_string" "suffix" {
  length  = 4
  lower   = true
  upper   = false
  numeric = true
  special = false
}
resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.location
}
# resource "azurerm_resource_group" "rg" {
#   name     = "demo-func-rg"
#   location = "eastus"
# }

# Storage account name rules: lowercase, 3-24 chars, globally unique
# locals {
#   sa_base = replace(lower("${var.function_name}sa${random_string.suffix.result}"), "-", "")
#   sa_name = substr(local.sa_base, 0, 24)
# }

resource "azurerm_storage_account" "sa" {
  name = substr(lower(replace("${var.function_name}sa", "-", "")), 0, 24)
#  name                     = lower(replace("${var.function_name}sa", "-", ""))[0:24] # storage account name rules
  # name                     = local.sa_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  # allow_blob_public_access = false   # allow_blob_public_access removed for compatibility
  min_tls_version          = "TLS1_2"
  blob_properties {
    # disable public access
    default_service_version = "2021-06-08"
  }
}

resource "azurerm_app_service_plan" "plan" {
  name                = "${var.function_name}-plan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "Linux"
  reserved            = true

  sku {
    tier = "Standard"  # Consumption
    size = "S1"
    capacity = 1

  }
}

resource "azurerm_linux_function_app" "function" {
  name                = var.function_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_app_service_plan.plan.id
  storage_account_name       = azurerm_storage_account.sa.name
  storage_account_access_key = azurerm_storage_account.sa.primary_access_key
  functions_extension_version = "~4" # Azure Functions runtime version

  site_config {
    application_stack {
      # Example for Node or Python - adjust as needed
      # For Python use `python_version = "3.9"` plus worker runtime in app_settings
      node_version = "18"
    }
    # ftps_state = "Disabled"
  }
 
 
  app_settings = {
    FUNCTIONS_WORKER_RUNTIME   = "node"   # change to "python" or "dotnet" as needed
    WEBSITE_RUN_FROM_PACKAGE   = "1"
    FUNCTIONS_EXTENSION_VERSION  = "~4"
    AzureWebJobsStorage        = azurerm_storage_account.sa.primary_connection_string
  }
}

