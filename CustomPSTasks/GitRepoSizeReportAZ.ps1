$env:AZURE_DEVOPS_EXT_PAT = '<pat>' #https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops&tabs=preview-page

$orgUrl = "https://dev.azure.com/<org>"
$teamProject = "<team_project>"

az devops configure -d organization=$orgUrl project=$teamProject

$repos = az repos list | ConvertFrom-Json #get repositories if team project

if ($repos.count -gt 0)
{
    Write-Host "|NAME|SIZE (MB)|DEFAULT BRANCH|"
    Write-Host "|----|----:|----|"
}

foreach($repo in $repos)
{
    $mbsize = 0

    if ($repo.size -gt 0)
    {
        $mbsize = $repo.size / (1024*1024)
    }

     Write-Host "|" $repo.name "|" $mbsize "|" $repo.defaultBranch "|"
}