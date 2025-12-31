locals {
  prefix = "mi"
}

module "regions" {
  source  = "Azure/regions/azurerm"
  version = ">= 0.3.0"

  recommended_regions_only = true
}

resource "random_integer" "region_index" {
  max = length(module.regions.regions) - 1
  min = 0
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = ">= 0.3.0"
}

resource "azurerm_resource_group" "servicebus" {
  location = "westeurope"
  name     = "servicebus"
}

resource "azurerm_user_assigned_identity" "servicebus" {
  location            = azurerm_resource_group.servicebus.location
  name                = "servicebus-${local.prefix}"
  resource_group_name = azurerm_resource_group.servicebus.name
}

module "servicebus" {
  source   = "Azure/avm-res-servicebus-namespace/azurerm"
  version = "0.4.0"

  location            = azurerm_resource_group.servicebus.location
  name                = "${module.naming.servicebus_namespace.name_unique}-${local.prefix}"
  resource_group_name = azurerm_resource_group.servicebus.name
  managed_identities = {
    system_assigned            = true
    user_assigned_resource_ids = [azurerm_user_assigned_identity.servicebus.id]
  }
  sku = var.sku
}

resource "azurerm_servicebus_queue" "example" {
  name         = "keda-queue"
  namespace_id = module.servicebus.resource_id

  # Optional: Configure queue properties
  default_message_ttl = "P1D"  # 1 day
  max_delivery_count  = 10
}

