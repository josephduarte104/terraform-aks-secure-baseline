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

module "jumpbox" {
  source                  = "./modules/jumpbox"
  tags                    = local.tags
  location                = var.location
  resource_group          = azurerm_resource_group.app-rg.name 
  vnet_id                 = module.hub_network.vnet_id
  subnet_id               = module.hub_network.subnet_ids["Default"]
  dns_zone_name           = join(".", slice(split(".", module.azure_aks.private_fqdn), 1, length(split(".", module.azure_aks.private_fqdn)))) 
  dns_zone_resource_group = module.azure_aks.node_resource_group
  add_to_dns              = false

  depends_on              = [module.azure_aks]
}

# module "appgateway" {
#   source                  = "./modules/app_gateway"
#   name                    = "appgateway"
#   tags                    = local.tags
#   location                = var.location
#   resource_group          = azurerm_resource_group.app-rg.name 
#   subnet_id               = module.spoke_network.subnet_ids["applicationgateways"]

#   depends_on              = [module.spoke_network]
# }