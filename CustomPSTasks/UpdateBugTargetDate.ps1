$env:AZURE_DEVOPS_EXT_PAT = '<pat>' # https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops&tabs=preview-page#create-personal-access-tokens-to-authenticate-access
$azdOrg = "https://dev.azure.com/<org_name>"
$azdProject = "<team_project_name>"
$workItemType = "Bug"

$queryWiql = "SELECT [System.Id], [System.CreatedDate] FROM WorkItems WHERE [System.TeamProject] = '$azdproject'  AND  [System.WorkItemType] = '$workItemType'  AND  [System.State] = 'New'  AND  [Microsoft.VSTS.Scheduling.DueDate] = '' ORDER BY [System.Id]"

az devops configure -d organization=$azdOrg project=$azdProject

$workItems = (az boards query --wiql "$queryWiql" | ConvertFrom-Json)

foreach ($workItem in $workItems)
{
    Write-Host "Process the work item" $workItem.id

    $createdDate = [datetime]::ParseExact(($workItem.fields.'System.CreatedDate').Substring(0,10), "yyyy-MM-dd", $null)
    $targetDateStr = $createdDate.AddDays(12).ToString('yyyy-MM-dd')

    az boards work-item update --id $workItem.id --fields "Microsoft.VSTS.Scheduling.DueDate=$targetDateStr" --discussion "Updated by CLI"
}