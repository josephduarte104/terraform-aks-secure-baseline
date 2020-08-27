output vnet_resource {
  description = "Generated VNET resource"
  value = azurerm_virtual_network.vnet
}

output vnet_id {
  description = "Generated VNET ID"
  value       = azurerm_virtual_network.vnet.id
}

output subnet_ids {
  description = "Generated subnet IDs map"
  value       = { for subnet in azurerm_subnet.subnet : subnet.name => subnet.id }
}
