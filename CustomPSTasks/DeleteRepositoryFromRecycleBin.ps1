$org = "<org>"
$teamProject = "<team_project_name>"
$user = ""
$token = "<pat>" #https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops&tabs=preview-page

$listDeletedRepo = "https://dev.azure.com/$org/$teamProject/_apis/git/recycleBin/repositories?api-version=5.1-preview.1"

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$token)))

$resultDeletedRepo = Invoke-RestMethod -Uri $listDeletedRepo -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}

foreach ($repo in $resultDeletedRepo.value)
{    

    $hardDeleteRepo = "https://dev.azure.com/$org/$teamProject/_apis/git/recycleBin/repositories/" + $repo.id + "?api-version=5.1-preview.1"

    Invoke-RestMethod -Uri $hardDeleteRepo -Method Delete -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}

    Write-Host "Deleted repo:" $repo.name
}