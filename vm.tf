provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-windowsserver"
  location = "brazilsouth"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "windows-vnet"
  address_space       = ["10.0.0.0/16", "192.168.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "winserver-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "publicip" {
  name                    = "vmwinserver-publicip"
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  allocation_method       = "Dynamic"
  idle_timeout_in_minutes = 30
  domain_name_label       = "vmwinservertf"
}

resource "azurerm_network_interface" "nic" {
  name                = "vmwinserver-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipexterno-config"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.publicip.id
  }
}

resource "azurerm_network_security_group" "nsg" {
  name                = "vmwinserver-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

variable "regras_entrada" {
  type        = map(any)
  description = "Lista de Portas de entrada liberadas no NSG"
  default = {
    101 = 80
    102 = 443
    103 = 3389
    104 = 22
  }
}

resource "azurerm_network_security_rule" "regras_entrada_liberada" {
  for_each                    = var.regras_entrada
  resource_group_name         = azurerm_resource_group.rg.name
  name                        = "porta_entrada_${each.value}"
  priority                    = each.key
  destination_port_range      = each.value
  direction                   = "Inbound"
  access                      = "Allow"
  source_port_range           = "*"
  protocol                    = "TCP"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_windows_virtual_machine" "vmwin" {
  name                = "winserver"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  size           = "Standard_B1ls"
  admin_username = "Adminuser"
  admin_password = "Claudio@1994"

  network_interface_ids = [azurerm_network_interface.nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}