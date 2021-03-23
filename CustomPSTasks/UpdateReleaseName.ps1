$user = ""
$token = $env:SYSTEM_ACCESSTOKEN

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$token)))
$orgUrl = "$env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI"
$teamProject = "$env:SYSTEM_TEAMPROJECT"
$commitId = "$env:BUILD_SOURCEVERSION"
$repoName = "$env:BUILD_REPOSITORY_NAME"

$restApiGetCommit = "$orgUrl/$teamProject/_apis/git/repositories/$repoName/commits/$commitId`?api-version=6.0"

function InvokeGetRequest ($GetUrl)
{   
    return Invoke-RestMethod -Uri $GetUrl -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}
}

$resCommit = InvokeGetRequest $restApiGetCommit

$commitArray = $resCommit.comment -split '\n'

if (-not [string]::IsNullOrEmpty($commitArray[0]))
{
    Write-Host "##vso[release.updatereleasename]"$commitArray[0]
}
