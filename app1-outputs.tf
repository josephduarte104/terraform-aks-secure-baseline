output "keyvault_name" {
 description = "Keyvault name"
 value       = azurerm_key_vault.vault.name
}

output "ssh_command" {
 value = "ssh ${module.jumpbox.jumpbox_username}@${module.jumpbox.jumpbox_ip}"
}

output "jumpbox_password" {
 description = "Jumpbox Admin Passowrd"
 value       = module.jumpbox.jumpbox_password
}