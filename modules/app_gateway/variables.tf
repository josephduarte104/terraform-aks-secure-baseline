variable "name" {
  description     = "Name of app gateway"
  type            = string
  default         = "app-gw"
}

variable "resource_group" {
  description     = "Resource group where app gateway will be created"
  type            = string    
}

variable "location" {
  description     = "Region where app gateway will be created"
  type            = string
  default         = "eastus"
}

variable "tags" {
  description = "Tags to apply to resources"
  default     = null
}

variable "subnet_id" {
  description = "Gateway subnet id"
  type        = string 
}

variable "backend_ip_addresses" {
  description = "backend ip addresses for pool"
  type        = list(string)
  default     = null
}

variable "identity_ids" {
  description = "user assigned identity for app gateway"
  type        = list(string)
  default     = null
}