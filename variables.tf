############################################
# General
############################################

variable "location" {
  description = "Azure region where all resources will be deployed"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-networking"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    environment = "dev"
    owner       = "platform-team"
  }
}

############################################
# Virtual Network
############################################

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
  default     = "vnet-hub"
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

############################################
# Subnet
############################################

variable "subnet_name" {
  description = "Name of the subnet"
  type        = string
  default     = "subnet-default"
}

variable "subnet_address_prefix" {
  description = "Address prefix for the subnet"
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

############################################
# Optional / Common Enhancements
############################################

variable "dns_servers" {
  description = "Custom DNS servers for the virtual network"
  type        = list(string)
  default     = []
}

variable "enable_ddos_protection" {
  description = "Enable DDoS protection on the virtual network"
  type        = bool
  default     = false
}
