output backend_address_pool {
  value = azurerm_application_gateway.network.backend_address_pool[0].ip_addresses
}
