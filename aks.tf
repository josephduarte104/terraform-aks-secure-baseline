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


