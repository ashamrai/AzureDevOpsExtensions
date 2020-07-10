$user = ""
$token = "$(System.AccessToken)"
$teamProject = "$(System.TeamProject)"
$repoName = "$(Build.Repository.Name)"
$orgUrl = "$(System.TeamFoundationCollectionUri)"
$commitId = "$(Build.SourceVersion)"

$skipSteps = @{"Custom.SkipPredeploy" = "*skip_pre*"; "Custom.SkipPostdeploy" = "*skip_post*"; "Custom.SkipUpdate" = "*skip_update*"}

if ([string]::IsNullOrEmpty($commitId))
{
    Write-Host "CommitId is not defined"
    exit 0;
}

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$token)))
 
$uriGetCommit = "$orgUrl/$teamProject/_apis/git/repositories/$repoName/commits/$commitId" + "?api-version=5.1"

Write-Host $uriGetCommit

$resultCommit = Invoke-RestMethod -Uri $uriGetCommit -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}

$splits = $resultCommit.comment -split '\n'
Write-Host $splits[0]

foreach ($key in $skipSteps.Keys)
{
    if ($splits[0] -like $skipSteps[$key])
    {
        Write-Host "##vso[task.setvariable variable=$key]YES"
    }
}
