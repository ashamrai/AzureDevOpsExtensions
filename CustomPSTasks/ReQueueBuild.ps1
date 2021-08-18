$token = "$(System.AccessToken)" 

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$token)))
$orgUrl = "$(System.CollectionUri)"
$teamProject = "$(System.TeamProject)"

$buildId = '$(Build.BuildId)'
$buildDefId = '$(System.DefinitionId)'

$restReRunBuild = "$orgUrl/$teamProject/_apis/build/builds?definitionId=$buildDefId&api-version=6.1-preview.6"
$restGetBuildLogs = "$orgUrl/$teamProject/_apis/build/builds/$buildId/logs?api-version=6.0"

function InvokeGetRequest ($GetUrl)
{    
    return Invoke-RestMethod -Uri $GetUrl -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}    
}

function InvokePostRequest ($PostUrl)
{    
    return Invoke-RestMethod -Uri $PostUrl -Method Post -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}
}

$restGetBuildLogs

$buildLogs = InvokeGetRequest $restGetBuildLogs

$searchPhrase = "The operation could not continue because the target database was modified after schema comparison was completed"

foreach ($buildLog in $buildLogs.value)
{
    $buildRes = InvokeGetRequest $buildLog.url    

    if ($buildRes.Contains($searchPhrase))
    {
        Write-Host "Needs to restart"

        $restReRunBuild

        $result = InvokePostRequest $restReRunBuild

        $result
    }
}
