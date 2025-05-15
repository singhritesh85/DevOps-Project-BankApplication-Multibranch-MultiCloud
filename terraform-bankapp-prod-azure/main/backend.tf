terraform {
  backend "azurerm" {
    resource_group_name  = "ritesh"
    storage_account_name = "terraformstate08022024"
    container_name       = "terraform-state"
    key                  = "state/terraform.tfstate"
    subscription_id      = "5XXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"  ### Provide Subscription ID of your Azure Account.
  }
}
