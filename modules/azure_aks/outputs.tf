output principal_id {
  description = "Generated Principal ID"
  value       = azurerm_kubernetes_cluster.modaks.identity[0].principal_id
}

output cluster_resource_id {
  value       = azurerm_kubernetes_cluster.modaks.id
}
