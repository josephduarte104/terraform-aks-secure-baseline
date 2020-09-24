variable "active_backend_pool" {
  description = "which backend to activate via the app gateway"
  type        = string 
  validation {
    condition     = (var.active_backend_pool == "blue" || var.active_backend_pool == "green")
    error_message = "Must be one of blue or green."
  }
  default     = "blue"
}

variable "enable_blue_pool" {
  type = bool 
  description = "whether or not a blue pool exists"
}

variable "enable_green_pool" {
  type = bool 
  description = "whether or not a green pool exists"
}

variable "drain_green_pool" {
  type = bool 
  description = "whether or not to taint the green pool to drain pods from it"
}

variable "drain_blue_pool" {
  type = bool 
  description = "whether or not to taint the blue pool to drain pods from it"
}