variable "name" {
  description = "The name of the AKS cluster"
  type        = string
}

variable "container_registry_id" {
  description = "Resource id of the ACR"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the AKS cluster resource group"
  type        = string
}

variable "location" {
  description = "Azure region of the AKS cluster"
  type        = string
}

variable "vnet_subnet_id" {
  description = "Resource id of the Virtual Network subnet"
  type        = string
}

variable "private_cluster" {
  description = "Deploy an AKS cluster without a public accessible API endpoint."
  type        = bool
}

variable "sla_sku" {
  description = "Define the SLA under which the managed master control plane of AKS is running."
  type        = string
  default     = "Free"
}

variable "api_auth_ips" {
  description = "Whitelist of IP addresses to access control plane"
  type        = list(string)
}

variable "default_node_pool" {
  description = "The object to configure the default node pool with number of worker nodes, worker node VM size and Availability Zones."
  type = object({
    name                           = string
    vm_size                        = string
  })
}

variable "enable_blue_system_pool" {
  default = false
  type    = bool
}

variable "enable_blue_user_pool" {
  default = false
  type    = bool
}

variable "enable_green_system_pool" {
  default = false
  type    = bool
}

variable "enable_green_user_aks" {
  default = false
  type    = bool
}

variable "blue_system_pool" {
  description = "Definition for Blue System Pool"
  type = object ({
    name                           = "blue_system"
    node_count                     = number
    vm_size                        = string
    zones                          = list(string)
    node_os                        = string
    azure_tags                     = map(string)
    cluster_auto_scaling           = bool
    cluster_auto_scaling_min_count = number
    cluster_auto_scaling_max_count = number
    orchestrator_version           = string
  })
}

variable "green_system_pool" {
  description = "Definition for Green System Pool"
  type = object ({
    name                           = "green_system"
    node_count                     = number
    vm_size                        = string
    zones                          = list(string)
    node_os                        = string
    azure_tags                     = map(string)
    cluster_auto_scaling           = bool
    cluster_auto_scaling_min_count = number
    cluster_auto_scaling_max_count = number
    orchestrator_version           = string
  })
}

variable "blue_user_pool" {
  description = "Definition for Blue User Pool"
  type = object ({
    name                           = "blue_user"
    node_count                     = number
    vm_size                        = string
    zones                          = list(string)
    node_os                        = string
    azure_tags                     = map(string)
    cluster_auto_scaling           = bool
    cluster_auto_scaling_min_count = number
    cluster_auto_scaling_max_count = number
    orchestrator_version           = string
  })
}

variable "green_user_pool" {
  description = "Definition for Green User Pool"
  type = object ({
    name                           = "green_user"
    node_count                     = number
    vm_size                        = string
    zones                          = list(string)
    node_os                        = string
    azure_tags                     = map(string)
    cluster_auto_scaling           = bool
    cluster_auto_scaling_min_count = number
    cluster_auto_scaling_max_count = number
    orchestrator_version           = string
  })
}

variable "addons" {
  description = "Defines which addons will be activated."
  type = object({
    oms_agent             = bool
    kubernetes_dashboard  = bool
    azure_policy          = bool
  })

  default = {
    oms_agent             = false
    kubernetes_dashboard  = false
    azure_policy          = false
  }

}
