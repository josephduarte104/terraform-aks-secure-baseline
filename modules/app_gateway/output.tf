output backend_address_pool {
  value = azurerm_application_gateway.network.backend_address_pool[0].ip_addresses
}

output blue_backend_ip_addresses {
  value = var.blue_backend_ip_addresses
}

output green_backend_ip_addresses {
  value = var.green_backend_ip_addresses
}