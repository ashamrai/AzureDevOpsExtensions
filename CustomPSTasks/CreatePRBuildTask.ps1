$user = ""
$token = "$(System.AccessToken)"
$branchTarget = "$(Build.SourceBranch)"
$branchSource = "refs/heads/master"
$branchTragetPath = $branchTarget -replace "refs/heads/", ""
$teamProject = "$(System.TeamProject)"
$repoName = "$(Build.Repository.Name)"
$orgUrl = "$(System.CollectionUri)"

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$token)))
 
$uriBranchStatus = "$orgUrl/$teamProject/_apis/git/repositories/$repoName/stats/branches?name=$branchTragetPath&api-version=5.1"
$uriCheckActivePR = "$orgUrl/$teamProject/_apis/git/repositories/$repoName/pullrequests?searchCriteria.targetRefName=$branchTarget&searchCriteria.sourceRefName=$branchSource&api-version=5.1"
$uriCreatePR = "$orgUrl/$teamProject/_apis/git/repositories/$repoName/pullrequests?api-version=5.1"

$resultStatus = Invoke-RestMethod -Uri $uriBranchStatus -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}

if ($resultStatus.behindCount -eq 0)
{
    Write-Host "Current branch contains last changes from master"
    Return
}

$resultActivePR = Invoke-RestMethod -Uri $uriCheckActivePR -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}

if ($resultActivePR.count -gt 0) 
{
    Write-Host "PR exists already"
    Return
}

$bodyCreatePR = "{sourceRefName:'$branchSource',targetRefName:'$branchTarget',title:'Sync changes from $branchSource'}"

$result = Invoke-RestMethod -Uri $uriCreatePR -Method Post -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -Body $bodyCreatePR

Write-Host "Created PR" $result.pullRequestId