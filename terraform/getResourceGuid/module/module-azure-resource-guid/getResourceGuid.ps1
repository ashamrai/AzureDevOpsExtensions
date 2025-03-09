param ( $sbID, $rgName, $resName, $appId, $appToken, $appTenantId )

az login --service-principal -u $appId --password=$appToken --tenant $appTenantId --allow-no-subscriptions

$resourceJson = az rest --method get --uri https://management.azure.com/subscriptions/$sbID/resourceGroups/$rgName/providers/Microsoft.Network/privateEndpoints/$resName`?api-version=2023-04-01 | ConvertFrom-Json

Set-Content -Path "./modules/module-azure-resource-guid/resourceGuid.txt" $resourceJson.properties.resourceGuid -NoNewline
