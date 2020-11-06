resource "azurerm_resource_group" "hub-rg" {
  name     = "AKS2-HUB-RG" 
  tags     = local.tags
  location = local.location
}

module "hub_network" {
  source              = "./modules/vnet"
  tags                = local.tags
  resource_group_name = azurerm_resource_group.hub-rg.name 
  location            = local.location
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
    },
    {
      name : "other"
      address_prefixes : ["10.200.0.160/27"]
      private_link_endpoint_policies_enforced: false
      private_link_service_policies_enforced: false
    }
  ]
}

module "firewall" {
  source         = "./modules/firewall"
  tags           = local.tags
  resource_group = azurerm_resource_group.hub-rg.name 
  location       = local.location
  pip_name       = "pip-fw-default"
  fw_name        = "fw-hub"
  subnet_id      = module.hub_network.subnet_ids["AzureFirewallSubnet"]
}

module "routetable" {
  source              = "./modules/route_table"
  tags                = local.tags
  resource_group      = azurerm_resource_group.app-rg.name 
  location            = local.location
  rt_name             = "kubenetfw_fw_rt"
  r_name              = "kubenetfw_fw_r"
  firewall_private_ip = module.firewall.fw_private_ip
  subnet_id           = module.spoke_network.subnet_ids["clusternodes"]
  
  depends_on          = [module.spoke_network]
}

