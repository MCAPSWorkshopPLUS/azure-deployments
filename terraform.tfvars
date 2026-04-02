############################################
# General
############################################

location             = "eastus"
resource_group_name  = "rg-networking-dev"

############################################
# Virtual Network
############################################

vnet_name           = "vnet-hub"
vnet_address_space  = ["10.0.0.0/16"]

############################################
# Subnet
############################################

subnet_name            = "subnet-default"
subnet_address_prefix = ["10.0.1.0/24"]

############################################
# Optional / Common Enhancements
############################################

dns_servers            = []
enable_ddos_protection = false
