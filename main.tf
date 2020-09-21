locals {
  # All variables used in this file should be 
  # added as locals here 
  location       = var.location
  prefix         = var.prefix != null ? var.prefix : random_pet.petname.id 
  vault_name     = "${local.prefix}-vault"
  registry_name  = "${local.prefix}-acr"
  # Common tags should go here
  tags           = {
    created_by   = "Terraform"
  }
}

resource "random_pet" "petname" {
  length        = 2
  separator     = "-"
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "hub-rg" {
  name     = "AKS2-HUB-RG" 
  tags     = local.tags
  location = var.location
}

resource "azurerm_resource_group" "app-rg" {
  name     = "AKS2-APP-RG" 
  tags     = local.tags
  location = var.location
}

module "hub_network" {
  source              = "./modules/vnet"
  tags                = local.tags
  resource_group_name = azurerm_resource_group.hub-rg.name 
  location            = var.location
  vnet_name           = "vnet-hub" 
  address_space       = ["10.200.0.0/24"]
  subnets = [
    {
      name : "AzureFirewallSubnet"
      address_prefixes : ["10.200.0.0/26"]
      private_link_endpoint_policies_enforced: false
      private_link_service_policies_enforced: false
    },
    {
      name : "GatewaySubnet"
      address_prefixes : ["10.200.0.64/27"]
      private_link_endpoint_policies_enforced: false
      private_link_service_policies_enforced: false
    },
    {
      name : "AzureBastionSubnet"
      address_prefixes : ["10.200.0.96/27"]
      private_link_endpoint_policies_enforced: false
      private_link_service_policies_enforced: false
    },
    {
      name : "default"
      address_prefixes : ["10.200.0.128/27"]
      private_link_endpoint_policies_enforced: false
      private_link_service_policies_enforced: false
    }
  ]
}

module "spoke_network" {
  source              = "./modules/vnet"
  tags                = local.tags
  resource_group_name = azurerm_resource_group.app-rg.name 
  location            = var.location
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

module "firewall" {
  source         = "./modules/firewall"
  tags           = local.tags
  resource_group = azurerm_resource_group.hub-rg.name 
  location       = var.location
  pip_name       = "pip-fw-default"
  fw_name        = "fw-hub"
  subnet_id      = module.hub_network.subnet_ids["AzureFirewallSubnet"]
}

module "routetable" {
  source              = "./modules/route_table"
  tags                = local.tags
  resource_group      = azurerm_resource_group.hub-rg.name 
  location            = var.location
  rt_name             = "kubenetfw_fw_rt"
  r_name              = "kubenetfw_fw_r"
  firewall_private_ip = module.firewall.fw_private_ip
  subnet_id           = module.spoke_network.subnet_ids["clusternodes"]
  
  depends_on          = [module.spoke_network]
}

module "appgateway" {
  source                  = "./modules/app_gateway"
  name                    = "appgateway"
  tags                    = local.tags
  location                = var.location
  resource_group          = azurerm_resource_group.app-rg.name 
  subnet_id               = module.spoke_network.subnet_ids["applicationgateways"]
  backend_ip_addresses    = ["10.240.4.4"]
  identity_ids            = [azurerm_user_assigned_identity.appw-to-keyvault.id]

  depends_on              = [module.spoke_network]
}

module "azure_aks" {
  depends_on                        = [module.routetable, azurerm_container_registry.acr]

  source                            = "./modules/azure_aks"
  name                              = "bg-aks"
  container_registry_id             = azurerm_container_registry.acr.id 
  control_plane_kubernetes_version  = "1.17.9"
  resource_group_name               = azurerm_resource_group.app-rg.name
  location                          = var.location
  vnet_subnet_id                    = module.spoke_network.subnet_ids["clusternodes"]
  api_auth_ips                      = null
  private_cluster                   = false 
  sla_sku                           = "Free"

  default_node_pool = {
    name                           = "default"
    vm_size                        = "Standard_D2_v2"
  }
  # enable_blue_pool=true will ensure 2 node pools exist (bluesystem, blueuser)
  # enable_blue_pool=false will delete bluesystem and blueuser node pools
  # drain_blue_pool=true will taint and drain the blue node pool (bluesystem and blueuser).  It does NOT delete it.
  enable_blue_pool                  = true
  drain_blue_pool                   = false
  blue_pool = {
    name                            = "blue"
    system_min_count                = 1 
    system_max_count                = 3
    user_min_count                  = 1 
    user_max_count                  = 6
    system_vm_size                  = "Standard_D2_v2"
    user_vm_size                    = "Standard_D2_v2"
    zones                           = ["1", "2", "3"]
    node_os                         = "Linux"
    azure_tags                      = null
    pool_kubernetes_version         = "1.17.7" 
  }
  
  # enable_green_pool=true will ensure 2 node pools exist (greensystem, greenuser)
  # enable_green_pool=false will delete greensystem and greenuser node pools
  # drain_green_pool=true will taint and drain the green node pool (greensystem and greenuser).  It does NOT delete it.
  enable_green_pool                 = false
  drain_green_pool                  = false
  green_pool = {
    name                            = "green"
    system_min_count                = 1 
    system_max_count                = 3
    user_min_count                  = 1 
    user_max_count                  = 3
    system_vm_size                  = "Standard_D2_v2"
    user_vm_size                    = "Standard_D2_v2"
    zones                           = ["1", "2", "3"]
    node_os                         = "Linux"
    azure_tags                      = null
    pool_kubernetes_version         = "1.17.7" 
  }
}

resource "azurerm_role_assignment" "Contributor" {
  role_definition_name        = "Contributor"
  scope                       = azurerm_resource_group.app-rg.id
  principal_id                = module.azure_aks.principal_id
}

resource "azurerm_public_ip" "bastion" {
  name                = "bastionpip"
  location            = azurerm_resource_group.hub-rg.location
  resource_group_name = azurerm_resource_group.hub-rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bastion" {
  name                = "bastion"
  location            = azurerm_resource_group.hub-rg.location
  resource_group_name = azurerm_resource_group.hub-rg.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = module.hub_network.subnet_ids["AzureBastionSubnet"]
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}

resource "azurerm_key_vault" "vault" {
  name                  = replace(local.vault_name, "-", "")
  location              = var.location
  resource_group_name   = azurerm_resource_group.app-rg.name
  sku_name              = "standard"
  tenant_id             = data.azurerm_client_config.current.tenant_id
  tags                  = local.tags
  
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = module.azure_aks.principal_id

    key_permissions = [
      "get","list","create","delete","encrypt","decrypt","unwrapKey","wrapKey"
    ]

    secret_permissions = [
      "get","list","set","delete"
    ]
  } 
  
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

# output managed_id {
#   value = azurerm_user_assigned_identity.appw-to-keyvault.principal_id 
# }

resource "azurerm_container_registry" "acr" {
  name                     = replace(local.registry_name, "-", "")
  resource_group_name      = azurerm_resource_group.app-rg.name
  location                 = var.location
  sku                      = "Premium"
  admin_enabled            = false
}

resource "azurerm_private_endpoint" "akv-endpoint" {
  name                = "nodepool-to-akv" 
  location            = var.location
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
  location            = var.location
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

# module "jumpbox" {
#   source                  = "./modules/jumpbox"
#   tags                    = local.tags
#   location                = var.location
#   resource_group          = azurerm_resource_group.app-rg.name 
#   vnet_id                 = module.hub_network.vnet_id
#   subnet_id               = module.hub_network.subnet_ids["Default"]
#   dns_zone_name           = join(".", slice(split(".", module.azure_aks.private_fqdn), 1, length(split(".", module.azure_aks.private_fqdn)))) 
#   dns_zone_resource_group = module.azure_aks.node_resource_group
#   add_to_dns              = false

#   depends_on              = [module.azure_aks]
# }

