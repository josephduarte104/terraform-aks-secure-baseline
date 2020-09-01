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
  name     = "AKS-HUB-RG" 
  tags     = local.tags
  location = var.location
}

resource "azurerm_resource_group" "app-rg" {
  name     = "AKS-APP-RG" 
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
    },
    {
      name : "GatewaySubnet"
      address_prefixes : ["10.200.0.64/27"]
    },
    {
      name : "AzureBastionSubnet"
      address_prefixes : ["10.200.0.96/27"]
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
    },
    {
      name : "clusteringressservices"
      address_prefixes : ["10.240.4.0/28"]
    },
    {
      name : "applicationgateways"
      address_prefixes : ["10.240.4.16/28"]
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
  source             = "./modules/route_table"
  tags               = local.tags
  resource_group     = azurerm_resource_group.hub-rg.name 
  location           = var.location
  rt_name            = "kubenetfw_fw_rt"
  r_name             = "kubenetfw_fw_r"
  firewal_private_ip = module.firewall.fw_private_ip
  subnet_id          = module.spoke_network.subnet_ids["clusternodes"]
  
  depends_on         = [module.spoke_network]
}

module "azure_aks" {
  depends_on                        = [module.routetable]

  source                            = "./modules/azure_aks"
  name                              = "terra-aks"
  container_registry_id             = null
  kubernetes_version                = "1.17.9"
  resource_group_name               = azurerm_resource_group.app-rg.name
  location                          = var.location
  vnet_subnet_id                    = module.spoke_network.subnet_ids["clusternodes"]
  api_auth_ips                      = null
  private_cluster                   = false
  sla_sku                           = "Free"

  default_node_pool = {
    name                           = "default1"
    vm_size                        = "Standard_D2_v2"
  }
  
  system_node_pools = {
    bluesystem = {
      node_count                      = 3
      vm_size                         = "Standard_D2_v2"
      zones                           = ["1", "2", "3"]
      node_os                         = "Linux"
      azure_tags                      = {
        Deployment = "Blue"
      }
      cluster_auto_scaling            = false
      cluster_auto_scaling_min_count  = null
      cluster_auto_scaling_max_count  = null
      orchestrator_version            = "1.17.7"
    },
    greensystem = {
      node_count                      = 3
      vm_size                         = "Standard_D2_v2"
      zones                           = ["1", "2", "3"]
      node_os                         = "Linux"
      azure_tags                      = {
        Deployment = "Green"
        Current = "true"
      }
      cluster_auto_scaling            = false
      cluster_auto_scaling_min_count  = null
      cluster_auto_scaling_max_count  = null
      orchestrator_version            = "1.16.13"
    }
  }

  user_node_pools = {
    blueuser = {
      node_count                      = 3
      vm_size                         = "Standard_D2_v2"
      zones                           = ["1", "2", "3"]
      node_os                         = "Linux"
      taints                          = null
      azure_tags                      = null
      cluster_auto_scaling            = false
      cluster_auto_scaling_min_count  = null
      cluster_auto_scaling_max_count  = null
      orchestrator_version            = "1.16.10" 
    }
  }
}

resource "azurerm_role_assignment" "Contributor" {
  role_definition_name        = "Contributor"
  scope                       = azurerm_resource_group.app-rg.id
  principal_id                = module.azure_aks.principal_id
}



