$token = "$(System.AccessToken)" 

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$token)))
$orgUrl = "$(System.CollectionUri)"
$teamProject = "$(System.TeamProject)"

$buildId = '$(Build.TriggeredBy.BuildId)'

$restGetBuild = "$orgUrl/$teamProject/_apis/build/builds/$buildId`?api-version=6.0"

function InvokeGetRequest ($GetUrl)
{    
    return Invoke-RestMethod -Uri $GetUrl -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}
}


$result = InvokeGetRequest $restGetBuild

$commit = $result.sourceVersion

& git checkout $commit
