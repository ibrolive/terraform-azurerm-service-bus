locals {
  prefix = "mi"
  skus   = ["Basic", "Standard", "Premium"]
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
  
  for_each = toset(local.skus)

  location            = azurerm_resource_group.servicebus.location
  name                = "${module.naming.servicebus_namespace.name_unique}-${each.value}-${local.prefix}"
  resource_group_name = azurerm_resource_group.servicebus.name
  managed_identities = {
    system_assigned            = true
    user_assigned_resource_ids = [azurerm_user_assigned_identity.servicebus.id]
  }
  sku = each.value
}

# Service Bus Queue (only for Standard and Premium SKUs)
resource "azurerm_servicebus_queue" "example" {
  for_each = toset([for sku in local.skus : sku if sku != "Basic"])

  name         = "keda-queue"
  namespace_id = module.servicebus[each.value].resource_id

  # Optional: Configure queue properties
  default_message_ttl = "P1D"  # 1 day
  max_delivery_count  = 10
}

