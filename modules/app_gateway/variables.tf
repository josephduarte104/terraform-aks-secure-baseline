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