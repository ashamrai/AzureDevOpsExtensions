#define the following var:
# sbID - subscrption Id
# rgName - resource group name
# resName - resource name
# appId - MS Entra ID application
# appToken - application secret
# appTenantId - MS Entra ID

resource "null_resource" "get_resource_giud" {
  provisioner "local-exec" {
  command = "pwsh -File ./modules/module-azure-resource-guid/getResourceGuid.ps1 -sbID ${var.sbID} -rgName ${var.rgName} -resName ${var.resName} -appId ${var.appId} -appToken ${var.appToken} -appTenantId ${var.appTenantId}"
}

data "local_file" "resource_guid_file" {
  filename   = "./modules/module-azure-resource-guid/resourceGuid.txt"
  depends_on = [null_resource.get_resource_giud]
}

# read the guid through: data.local_file.resource_guid_file.content
