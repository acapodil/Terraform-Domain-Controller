# Terraform
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    azuread = {
      source = "hashicorp/azuread"
    }
  }

  # backend "azurerm" {
  #   resource_group_name  = "TC-Terraform-State"
  #   storage_account_name = "tfstatefiles1"
  #   container_name       = "domaincontroller"
  #   key                  = "dc.terraform.tfstate"
  # }

}

provider "azurerm" {
  features {}
}

#Deploy RG
resource "azurerm_resource_group" "domain_controller_RG" {
  name     = var.rg-name
  location = var.location
}

#deploy VNet
resource "azurerm_virtual_network" "domain_controller_VNet" {
  name          = "${var.vnet_prefix}-VNet"
  address_space = ["10.0.0.0/16"]
  #dns_servers         = ["10.0.0.4"]
  location            = azurerm_resource_group.domain_controller_RG.location
  resource_group_name = azurerm_resource_group.domain_controller_RG.name
}

#Deploy Subnet
resource "azurerm_subnet" "domain_subnet" {
  name                 = "${var.subnet_prefix}-Subnet"
  resource_group_name  = azurerm_resource_group.domain_controller_RG.name
  virtual_network_name = azurerm_virtual_network.domain_controller_VNet.name
  address_prefixes     = ["10.0.0.0/24"]
}

#Deploy NIC
resource "azurerm_network_interface" "NIC" {
  name                = "DomainController-nic"
  location            = azurerm_resource_group.domain_controller_RG.location
  resource_group_name = azurerm_resource_group.domain_controller_RG.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.domain_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.0.4"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

#deploy NSG
resource "azurerm_network_security_group" "DC_NSG" {
  name                = "DomainNSG"
  location            = azurerm_resource_group.domain_controller_RG.location
  resource_group_name = azurerm_resource_group.domain_controller_RG.name

  security_rule {
    name                       = "enableRDP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Port_80_Inbound"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Port_80_Outbound"
    priority                   = 101
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

#associate NSG to NIC
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.NIC.id
  network_security_group_id = azurerm_network_security_group.DC_NSG.id
}

#create PIP
resource "azurerm_public_ip" "pip" {
  name                = "DomainController-pip"
  location            = azurerm_resource_group.domain_controller_RG.location
  resource_group_name = azurerm_resource_group.domain_controller_RG.name
  allocation_method   = "Static"

  tags = {
    environment = "Production"
  }
}

#deploy VM
resource "azurerm_windows_virtual_machine" "domain_controller" {
  name                = "PrimaryDC"
  location            = azurerm_resource_group.domain_controller_RG.location
  resource_group_name = azurerm_resource_group.domain_controller_RG.name
  admin_username      = var.adminUsername
  admin_password      = var.adminPassword
  size                = var.virtualMachineSize
  network_interface_ids = [
    azurerm_network_interface.NIC.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }
}

#Create OS disk 
resource "azurerm_managed_disk" "OS_Disk" {
  name                 = "PrimaryDC-disk1"
  location             = azurerm_resource_group.domain_controller_RG.location
  resource_group_name  = azurerm_resource_group.domain_controller_RG.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 20
}

#Create OS disk association
resource "azurerm_virtual_machine_data_disk_attachment" "attach_OS_Disk" {
  managed_disk_id    = azurerm_managed_disk.OS_Disk.id
  virtual_machine_id = azurerm_windows_virtual_machine.domain_controller.id
  lun                = 0
  caching            = "ReadWrite"
}

#Create OS disk 
resource "azurerm_managed_disk" "data_Disk" {
  name                 = "PrimaryDC-dataDisk"
  depends_on           = [azurerm_virtual_machine_data_disk_attachment.attach_OS_Disk]
  location             = azurerm_resource_group.domain_controller_RG.location
  resource_group_name  = azurerm_resource_group.domain_controller_RG.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 20
}

#Create OS disk association
resource "azurerm_virtual_machine_data_disk_attachment" "attach_data_Disk" {
  managed_disk_id    = azurerm_managed_disk.data_Disk.id
  virtual_machine_id = azurerm_windows_virtual_machine.domain_controller.id
  lun                = 1
  caching            = "ReadOnly"
}


//configure Auto-Shutdown of the VM to save on costs
resource "azurerm_dev_test_global_vm_shutdown_schedule" "rg" {
  virtual_machine_id = azurerm_windows_virtual_machine.domain_controller.id
  location           = azurerm_resource_group.domain_controller_RG.location
  enabled            = true

  daily_recurrence_time = "1600"
  timezone              = "Central Standard Time"


  notification_settings {
    enabled = false

  }
}

#Run DSC on VM- Configure as a domain controller
resource "azurerm_virtual_machine_extension" "configure_DC" {
  name                       = "congfigure_DC"
  virtual_machine_id         = azurerm_windows_virtual_machine.domain_controller.id
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.73"
  auto_upgrade_minor_version = true
  depends_on                 = [azurerm_virtual_machine_data_disk_attachment.attach_data_Disk]
  settings                   = <<SETTINGS
    {
      "modulesUrl": "https://github.com/acapodil/Terraform-Domain-Controller/blob/main/Scripts/DSC/builddc.zip?raw=true",
      "configurationFunction": "dsc_createdomain.ps1\\CreateADPDC",
            "properties": {
            "domainName": "${var.fqDomainName}",
            "addtlDataDiskSize": "20",
            "adminCreds": {
            "userName": "${var.adminUsername}",
            "password": "PrivateSettingsRef:adminPassword"
          }
       }

    }
SETTINGS
  protected_settings         = <<PROTECTED_SETTINGS
    {
      "Items": {
        "adminPassword" : "${var.adminPassword}"
      }
    }
PROTECTED_SETTINGS
}

#install ADConnect on DC 
resource "azurerm_virtual_machine_extension" "custom_script" {
  name                 = "install_ADConnect-DC"
  virtual_machine_id   = azurerm_windows_virtual_machine.domain_controller.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  depends_on           = [azurerm_virtual_machine_extension.configure_DC]

  settings = jsonencode({

    "fileUris" : ["https://raw.githubusercontent.com/acapodil/Terraform-Domain-Controller/main/Scripts/getADC2.ps1"]
    "commandToExecute" : "powershell -ExecutionPolicy Unrestricted -File getADC2.ps1"
  })

  tags = {
    environment = "ADConnect"
  }
}

