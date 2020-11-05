resource "azurerm_resource_group" "app-rg" {
  name     = "AKS2-APP-RG" 
  tags     = local.tags
  location = local.location
}

module "spoke_network" {
  source              = "./modules/vnet"
  tags                = local.tags
  resource_group_name = azurerm_resource_group.app-rg.name 
  location            = local.location
  vnet_name           = "vnet-spoke-app1"
  address_space       = ["10.240.0.0/16"]
  subnets = [
    {
      name : "clusternodes"
      address_prefixes : ["10.240.0.0/22"]
      private_link_endpoint_policies_enforced: false
      private_link_service_policies_enforced: false
    },
    {
      name : "clusteringressservices"
      address_prefixes : ["10.240.4.0/28"]
      private_link_endpoint_policies_enforced: false
      private_link_service_policies_enforced: false
    },
    {
      name : "applicationgateways"
      address_prefixes : ["10.240.4.16/28"]
      private_link_endpoint_policies_enforced: false
      private_link_service_policies_enforced: false
    },
    {
      name : "privatelinks"
      address_prefixes : ["10.240.4.32/28"]
      private_link_endpoint_policies_enforced: true
      private_link_service_policies_enforced: false
    },
    {
      name: "default",
      address_prefixes : ["10.240.4.48/28"]
      private_link_endpoint_policies_enforced: false
      private_link_service_policies_enforced: false   
    }
  ]
}

module "vnet_peering" {
  source              = "./modules/vnet_peering"
  tags                = local.tags
  vnet_1_name         = "vnet-hub"
  vnet_1_id           = module.hub_network.vnet_id
  vnet_1_rg           = azurerm_resource_group.hub-rg.name
  vnet_2_name         = "vnet-spoke-app1" 
  vnet_2_id           = module.spoke_network.vnet_id
  vnet_2_rg           = azurerm_resource_group.app-rg.name
  peering_name_1_to_2 = "HubToAppSpoke1"
  peering_name_2_to_1 = "AppSpoke1ToHub"
}

module "azure_aks" {
  depends_on                        = [module.routetable, azurerm_container_registry.acr, azuread_service_principal.aks-sp]

  source                            = "./modules/azure_aks"
  name                              = "bg-aks"
  container_registry_id             = azurerm_container_registry.acr.id 
  control_plane_kubernetes_version  = "1.18.8"
  resource_group_name               = azurerm_resource_group.app-rg.name
  location                          = local.location
  vnet_subnet_id                    = module.spoke_network.subnet_ids["clusternodes"]
  api_auth_ips                      = null
  private_cluster                   = true
  sla_sku                           = "Free"
  client_id                         = azuread_service_principal.aks-sp.application_id
  client_secret                     = azuread_service_principal_password.aks-sp-passwd.value
  
  default_node_pool = {
    name                           = "default"
    vm_size                        = "Standard_D2_v2"
  }

  addons = {
    oms_agent                       = true
    azure_policy                    = true
    kubernetes_dashboard            = false
  }

  # enable_blue_pool=true will ensure 2 node pools exist (bluesystem, blueuser)
  # enable_blue_pool=false will delete bluesystem and blueuser node pools
  # drain_blue_pool=true will taint and drain the blue node pool (bluesystem and blueuser).  It does NOT delete it.
  enable_blue_pool                  = var.enable_blue_pool 
  drain_blue_pool                   = var.drain_blue_pool 
  blue_pool = {
    name                            = "blue"
    system_min_count                = 1 
    system_max_count                = 3
    user_min_count                  = 1 
    user_max_count                  = 6
    system_vm_size                  = "Standard_D2_v2"
    user_vm_size                    = "Standard_DS2_v2"
    system_disk_size                = 128
    user_disk_size                  = 512 
    zones                           = ["1", "2", "3"]
    node_os                         = "Linux"
    azure_tags                      = null
    pool_kubernetes_version         = "1.17.9" 
  }

  # enable_green_pool=true will ensure 2 node pools exist (greensystem, greenuser)
  # enable_green_pool=false will delete greensystem and greenuser node pools
  # drain_green_pool=true will taint and drain the green node pool (greensystem and greenuser).  It does NOT delete it.
  enable_green_pool                 = var.enable_green_pool 
  drain_green_pool                  = var.drain_green_pool 
  green_pool = {
    name                            = "green"
    system_min_count                = 1 
    system_max_count                = 3
    user_min_count                  = 1 
    user_max_count                  = 3
    system_vm_size                  = "Standard_D2_v2"
    user_vm_size                    = "Standard_DS2_v2"
    system_disk_size                = 128 
    user_disk_size                  = 512 
    zones                           = ["1", "2", "3"]
    node_os                         = "Linux"
    azure_tags                      = null
    pool_kubernetes_version         = "1.17.9" 
  }
}


# App gateway is a hub component but is listed here because it more closely aligns with the workload
# in this particular configuration.  Since we are using one app gateway per application
module "appgateway" {
  source                    = "./modules/app_gateway"
  name                      = "appgateway"
  tags                      = local.tags
  location                  = local.location
  resource_group            = azurerm_resource_group.app-rg.name 
  subnet_id                 = module.spoke_network.subnet_ids["applicationgateways"]
  blue_backend_ip_addresses = ["10.240.4.4"]
  green_backend_ip_addresses= ["10.240.4.5"]
  active_backend            = var.active_backend_pool
  identity_ids              = [azurerm_user_assigned_identity.appw-to-keyvault.id]

  depends_on                = [module.spoke_network]
}


resource "azurerm_key_vault" "vault" {
  name                  = replace(local.vault_name, "-", "")
  location              = local.location
  resource_group_name   = azurerm_resource_group.app-rg.name
  sku_name              = "standard"
  tenant_id             = data.azurerm_client_config.current.tenant_id
  tags                  = local.tags
  
  
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "get","list","create","delete","encrypt","decrypt","unwrapKey","wrapKey"
    ]

    secret_permissions = [
      "get","list","set","delete"
    ]
  } 
  
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_user_assigned_identity.aksic-to-keyvault.principal_id
    
    key_permissions = [
      "get"
    ]

    secret_permissions = [
      "get"
    ]
  } 
  
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_user_assigned_identity.appw-to-keyvault.principal_id

    key_permissions = [
      "get"
    ]

    secret_permissions = [
      "get"
    ]
  } 
}


resource "azurerm_container_registry" "acr" {
  name                     = replace(local.registry_name, "-", "")
  resource_group_name      = azurerm_resource_group.app-rg.name
  location                 = local.location
  sku                      = "Premium"
  admin_enabled            = false
}

resource "azurerm_private_endpoint" "akv-endpoint" {
  name                = "nodepool-to-akv" 
  location            = local.location
  resource_group_name = azurerm_resource_group.app-rg.name
  subnet_id           = module.spoke_network.subnet_ids["privatelinks"]

  private_service_connection {
    name                            = "nodepoolsubnet-to-akv" 
    private_connection_resource_id  = azurerm_key_vault.vault.id
    is_manual_connection            = false
    subresource_names               = ["vault"]
  }
}

resource "azurerm_private_endpoint" "acr-endpoint" {
  name                = "nodepool-to-acr" 
  location            = local.location
  resource_group_name = azurerm_resource_group.app-rg.name
  subnet_id           = module.spoke_network.subnet_ids["privatelinks"]

  private_service_connection {
    name                            = "nodepoolsubnet-to-acr" 
    private_connection_resource_id  = azurerm_container_registry.acr.id
    is_manual_connection            = false
    subresource_names               = ["registry"]
  }
}

resource "azurerm_private_dns_zone" "dns-zone" {
  name                = "privatelink.azure.net"
  resource_group_name = azurerm_resource_group.app-rg.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "hublink" {
  name                  = "hubnetdnsconfig"
  resource_group_name   = azurerm_resource_group.app-rg.name 
  private_dns_zone_name = azurerm_private_dns_zone.dns-zone.name
  virtual_network_id    = module.spoke_network.vnet_id
  tags                  = local.tags
}

resource "azurerm_private_dns_a_record" "acr-dnsrecord" {
  name                = azurerm_container_registry.acr.name
  zone_name           = azurerm_private_dns_zone.dns-zone.name 
  resource_group_name = azurerm_resource_group.app-rg.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.acr-endpoint.private_service_connection[0].private_ip_address]

  depends_on          = [azurerm_private_endpoint.acr-endpoint]
}

resource "azurerm_private_dns_a_record" "akv-dnsrecord" {
  name                = azurerm_key_vault.vault.name
  zone_name           = azurerm_private_dns_zone.dns-zone.name 
  resource_group_name = azurerm_resource_group.app-rg.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.akv-endpoint.private_service_connection[0].private_ip_address]
  
  depends_on          = [azurerm_private_endpoint.akv-endpoint]
}

resource "azurerm_user_assigned_identity" "appw-to-keyvault" {
  resource_group_name = azurerm_resource_group.app-rg.name
  location            = azurerm_resource_group.app-rg.location
  tags                = local.tags
  name                = "appw-to-keyvault"
}

resource "azurerm_user_assigned_identity" "aksic-to-keyvault" {
  resource_group_name = azurerm_resource_group.app-rg.name
  location            = azurerm_resource_group.app-rg.location
  tags                = local.tags
  name                = "aksic-to-keyvault"
}

module "jumpbox" {
  source                  = "./modules/jumpbox"
  tags                    = local.tags
  location                = local.location
  resource_group          = azurerm_resource_group.app-rg.name 
  vnet_id                 = module.hub_network.vnet_id
  subnet_id               = module.hub_network.subnet_ids["default"]
  dns_zone_name           = join(".", slice(split(".", module.azure_aks.private_fqdn), 1, length(split(".", module.azure_aks.private_fqdn)))) 
  dns_zone_resource_group = module.azure_aks.node_resource_group
  add_to_dns              = false

  depends_on              = [module.azure_aks]
}

# data "azurerm_virtual_network" "vpn-vnet" {
#   name                = "GW-VNET"
#   resource_group_name = "VPN-RG"
# }

# module "vnet_peering_vpn" {
#   depends_on              = [module.hub_network] 
#   source                  = "./modules/vnet_peering"
#   tags                    = local.tags
#   vnet_1_name             = "vnet-hub"
#   vnet_1_id               = module.hub_network.vnet_id
#   vnet_1_rg               = azurerm_resource_group.hub-rg.name
#   vnet_2_name             = data.azurerm_virtual_network.vpn-vnet.name 
#   vnet_2_id               = data.azurerm_virtual_network.vpn-vnet.id 
#   vnet_2_rg               = "VPN-RG" 
#   peering_name_1_to_2     = "HubToVPN"
#   peering_name_2_to_1     = "VPNToHub"
#   vnet1_network_gateway   = false 
#   vnet1_use_remote_gateway= true 
#   vnet2_network_gateway   = true 
#   vnet2_use_remote_gateway= false 
# }

