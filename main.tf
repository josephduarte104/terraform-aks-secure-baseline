data "azurerm_client_config" "current" {}
data "azurerm_subscription" "primary" {}

resource "random_pet" "petname" {
  length        = 2
  separator     = "-"
}

resource "random_string" "random" {
  length        = 16
  special       = false
}

resource "azuread_application" "aks-app" {
  name                       = "${local.prefix}-aks-sp"
  available_to_other_tenants = false
  oauth2_allow_implicit_flow = true
}

resource "azuread_service_principal" "aks-sp" {
  application_id               = azuread_application.aks-app.application_id
  app_role_assignment_required = false
}

resource "azuread_service_principal_password" "aks-sp-passwd" {
  service_principal_id = azuread_service_principal.aks-sp.id
  value                = random_string.random.result
  end_date             = "2021-01-01T01:02:03Z" 
}

resource "azurerm_role_assignment" "contributor" {
  scope                       = azurerm_resource_group.app-rg.id 
  role_definition_name        = "Contributor"
  principal_id                = azuread_service_principal.aks-sp.id
}

# resource "azurerm_role_assignment" "net-contributor" {
#   scope                       = azurerm_resource_group.hub-rg.id
#   role_definition_name        = "Network Contributor"
#   principal_id                = azuread_service_principal.aks-sp.id
# }

# resource "azurerm_role_assignment" "contributor" {
#   scope                       = data.azurerm_subscription.primary.id
#   role_definition_name        = "Contributor"
#   principal_id                = azuread_service_principal.aks-sp.id
# }