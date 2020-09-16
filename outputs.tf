# output "ssh_command" {
#  value = "ssh ${module.jumpbox.jumpbox_username}@${module.jumpbox.jumpbox_ip}"
# }

# output "jumpbox_password" {
#  description = "Jumpbox Admin Passowrd"
#  value       = module.jumpbox.jumpbox_password
# }

output "gateway_ilb_ip" {
 description = "Gateway ip address"
 value       = module.appgateway.backend_address_pool
}