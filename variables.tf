variable "location" {
  default     = "eastus"
  description = "Location to Create all resources"
}

variable "rg-name" {
  description = "The name of the resource group to be created"
}

variable "adminUsername" {
  description = "The name of the resource group to be created"
}

variable "adminPassword" {
  description = "The name of the resource group to be created"
}

variable "virtualMachineSize" {
  default = "Standard_D2s_v3"
}

variable "image_publisher" {
  description = "Image Publisher"
}

variable "image_offer" {
  description = "Image Offer"
}

variable "image_sku" {
  description = "Image SKU"
}

variable "image_version" {
  description = "Image Version"
  default     = "latest"
}

variable "DSC_URI" {
  description = "DSC URI location"
  default     = "https://github.com/acapodil/Terraform-Domain-Controller/blob/main/Scripts/DSC/builddc.zip?raw=true"

}

variable "fqDomainName" {
  description = "The Domain name for the newly created ADDS domain. In order to use the AD Connect synchronization, this must be a routable domain that is verified in Office 365/Azure Active Directory. It must be a valid Internet domain name (for example, .com, .org, .net, .us, etc.)."

}

variable "vnet_prefix" {
  type = string
}

variable "subnet_prefix" {
  type = string
}

variable "subscriptionID" {
  type = string
}
variable "clientID" {
  type = string
}
variable "clientSecret" {
  type = string
}
variable "tenantID" {
  type = string
}


