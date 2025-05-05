# Create Resource Group
resource "azurerm_resource_group" "ds_rg" {
  name     = "${var.aks_prefix}-ds-rg"
  location = var.location
}

# Create VNet for Azure Entra Domain Services
resource "azurerm_virtual_network" "ds_vnet" {
  name                = "${var.aks_prefix}-ds-vnet"
  resource_group_name = azurerm_resource_group.ds_rg.name
  location            = azurerm_resource_group.ds_rg.location
  address_space       = ["172.25.0.0/16"]
}

# Create Subnet for VNet of Azure Entra Domain Services
resource "azurerm_subnet" "ds_subnet" {
  name                 = "default"         ###"${var.aks_prefix}-ds-subnet"
  resource_group_name  = azurerm_resource_group.ds_rg.name
  virtual_network_name = azurerm_virtual_network.ds_vnet.name
  address_prefixes     = ["172.25.1.0/24"]
  depends_on = [azurerm_virtual_network.ds_vnet]
}

# Create Network Security Group for Azure Entra Domain Services
resource "azurerm_network_security_group" "ds_nsg" {
  name                = "domain-services-nsg"
  location            = azurerm_resource_group.ds_rg.location
  resource_group_name = azurerm_resource_group.ds_rg.name

  security_rule {
    name                       = "AllowSyncWithAzureAD"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "AzureActiveDirectoryDomainServices"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowRD"
    priority                   = 201
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "CorpNetSaw"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowPSRemoting"
    priority                   = 301
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5986"
    source_address_prefix      = "AzureActiveDirectoryDomainServices"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowLDAPS"
    priority                   = 401
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "636"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Attach NSG with the created Subnet
resource "azurerm_subnet_network_security_group_association" "ds_nsg_subnet" {
  subnet_id                 = azurerm_subnet.ds_subnet.id
  network_security_group_id = azurerm_network_security_group.ds_nsg.id
}

# Create Azure Entra ID Group 
resource "azuread_group" "dc_admins" {
  display_name     = "AAD DC Administrators"
  security_enabled = true
}

# Create User in Azure Entra ID who can manage Azure Entra Domain Services
resource "azuread_user" "admin" {
  user_principal_name = "user1@singhritesh85.com"
  display_name        = "user1"
  password            = "Password@#795"
}

# Make this created user a member of the created group AAD DC Administrators
resource "azuread_group_member" "admin" {
  group_object_id  = azuread_group.dc_admins.object_id
  member_object_id = azuread_user.admin.object_id
}

# Published app for domain services
resource "azuread_service_principal" "ds_service_principal" {
  client_id = "2565bd9d-da50-47d4-8b85-4c97f669dc36"
  use_existing = true
}

# Creation of Azure Entra Domain Services
resource "azurerm_active_directory_domain_service" "entra_ds" {
  name                = "dexter-domainservices"
  location            = azurerm_resource_group.ds_rg.location
  resource_group_name = azurerm_resource_group.ds_rg.name
  domain_name           = "singhritesh85.com"
  sku                   = "Standard"     ### Select among Standard, Enterprise and Premium
  filtered_sync_enabled = false

  initial_replica_set {
    subnet_id = azurerm_subnet.ds_subnet.id
  }

  notifications {
###    additional_recipients = ["notifyA@example.net", "notifyB@example.org"]
    notify_dc_admins      = true
    notify_global_admins  = true
  }

  security {
    ntlm_v1_enabled = false
    tls_v1_enabled = false
    sync_ntlm_passwords = true
    sync_on_prem_passwords = true
    sync_kerberos_passwords = true
    kerberos_armoring_enabled = true
    kerberos_rc4_encryption_enabled = false
  }

  secure_ldap {
    enabled = true
    external_access_enabled = true
    pfx_certificate = filebase64("mykey.pfx")
    pfx_certificate_password = "Dexter@123"
  }

  tags = {
    Environment = "dev"
  }

  depends_on = [azuread_service_principal.ds_service_principal, azurerm_subnet_network_security_group_association.ds_nsg_subnet]
}
