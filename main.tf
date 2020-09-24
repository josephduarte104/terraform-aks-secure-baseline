resource "random_pet" "petname" {
  length        = 2
  separator     = "-"
}

data "azurerm_client_config" "current" {}


