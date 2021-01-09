$user = ""
$token = "<pat>" #https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops&tabs=preview-page

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$token)))
$orgUrl = "https://dev.azure.com/<org>"
$teamProject = "<team_project_name>"

$restApiGetRepos = "$orgUrl/$teamProject/_apis/git/repositories?api-version=6.1-preview.1"
$restApiGetHeads = "$orgUrl/$teamProject/_apis/git/repositories/{RepoName}/refs?filter={branch_path}&includeStatuses=true&latestStatusesOnly=true&api-version=6.1-preview.1"
$restApiGetCommit = "$orgUrl/$teamProject/_apis/git/repositories/{RepoName}/commits/{commitId}?api-version=6.1-preview.1"

function InvokeGetRequest ($GetUrl)
{    
    return Invoke-RestMethod -Uri $GetUrl -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}    
}

$repos = InvokeGetRequest($restApiGetRepos) #get repositories if team project

if ($repos.count -gt 0)
{
    Write-Host "|NAME|SIZE (MB)|DEFAULT BRANCH|LAST COMMIT DATE|"
    Write-Host "|----|----:|----|----:|"
}

foreach($repo in $repos.value)
{
    $mbsize = 0
    $lastChangesDate = ""

    if ($repo.size -gt 0)
    {
        $mbsize = $repo.size / (1024*1024)
    }

    $defaultBranchPath = ""
    $lastChangesDate = ""

    if (-not [string]::IsNullOrEmpty($repo.defaultBranch))
    {
        $defaultBranchPath = $repo.defaultBranch -replace "refs/", ""

        $headUrl = $restApiGetHeads -replace "{RepoName}", $repo.name
        $headUrl = $headUrl -replace "{branch_path}", $defaultBranchPath
        
        $refInfo = InvokeGetRequest($headUrl) #get info of the default branch       

        $commitUrl = $restApiGetCommit -replace "{RepoName}", $repo.name
        $commitUrl = $commitUrl -replace "{commitId}", $refInfo.value[0].objectId

        $cmtInfo = InvokeGetRequest($commitUrl) #get commit info

        $lastChangesDate = $cmtInfo.committer.date
    }

    Write-Host "|" $repo.name "|" $mbsize "|" $defaultBranchPath "|" $lastChangesDate "|"
}