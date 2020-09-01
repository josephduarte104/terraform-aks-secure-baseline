module "bg_aks" {
  depends_on                        = [module.routetable]

  source                            = "./modules/azure_aks"
  name                              = "bg-aks"
  container_registry_id             = null
  kubernetes_version                = "1.17.9"
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

  enable_blue_system_pool = false
  blue_system_pool = {
    node_count                      = 3
    vm_size                         = "Standard_D2_v2"
    zones                           = ["1", "2", "3"]
    node_os                         = "Linux"
    azure_tags                      = null
    cluster_auto_scaling            = true
    cluster_auto_scaling_min_count  = 3
    cluster_auto_scaling_max_count  = 6
    orchestrator_version            = "1.16.10" 
  }
  
  enable_green_system_pool = false
  green_system_pool = {
    node_count                      = 3
    vm_size                         = "Standard_D2_v2"
    zones                           = ["1", "2", "3"]
    node_os                         = "Linux"
    azure_tags                      = null
    cluster_auto_scaling            = true
    cluster_auto_scaling_min_count  = 3
    cluster_auto_scaling_max_count  = 6
    orchestrator_version            = "1.16.10" 
  }

  enable_blue_user_pool = false
  blue_user_pool = {
    node_count                      = 3
    vm_size                         = "Standard_D2_v2"
    zones                           = ["1", "2", "3"]
    node_os                         = "Linux"
    azure_tags                      = null
    cluster_auto_scaling            = true
    cluster_auto_scaling_min_count  = 3
    cluster_auto_scaling_max_count  = 6
    orchestrator_version            = "1.16.13" 
  }

  enable_green_user_pool = false
  green_user_pool = {
    node_count                      = 3
    vm_size                         = "Standard_D2_v2"
    zones                           = ["1", "2", "3"]
    node_os                         = "Linux"
    azure_tags                      = null
    cluster_auto_scaling            = true
    cluster_auto_scaling_min_count  = 3
    cluster_auto_scaling_max_count  = 6
    orchestrator_version            = "1.16.13" 
  }
}

resource "azurerm_role_assignment" "Contributor" {
  role_definition_name        = "Contributor"
  scope                       = azurerm_resource_group.app-rg.id
  principal_id                = module.azure_aks.principal_id
}


