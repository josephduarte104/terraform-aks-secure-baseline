locals {
  # All variables used in this file should be 
  # added as locals here 
  location                  = var.location
  
  # Common tags should go here
  tags           = {
    created_by = "Terraform"
  }
}

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
  address_space       = ["10.0.0.0/22"]
  subnets = [
    {
      name : "AzureFirewallSubnet"
      address_prefixes : ["10.0.0.0/24"]
    },
    {
      name : "GatewaySubnet"
      address_prefixes : ["10.0.1.0/24"]
    },
    {
      name : "AzureBastionSubnet"
      address_prefixes : ["10.0.2.0/24"]
    },
    {
      name : "Default"
      address_prefixes : ["10.0.3.0/24"]
    }
  ]
}

module "spoke_network" {
  source              = "./modules/vnet"
  tags                = local.tags
  resource_group_name = azurerm_resource_group.app-rg.name 
  location            = var.location
  vnet_name           = "vnet-spoke-app1"
  address_space       = ["10.0.4.0/22"]
  subnets = [
    {
      name : "clusternodes"
      address_prefixes : ["10.0.5.0/24"]
    },
    {
      name : "clusteringressservices"
      address_prefixes : ["10.0.6.0/24"]
    },
    {
      name : "applicationgateways"
      address_prefixes : ["10.0.7.0/24"]
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
  backend_ip_addresses    = ["10.0.6.6"]

  depends_on              = [module.spoke_network]
}

module "azure_aks" {
  depends_on                        = [module.routetable]

  source                            = "./modules/azure_aks"
  name                              = "bg-aks"
  container_registry_id             = null
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

