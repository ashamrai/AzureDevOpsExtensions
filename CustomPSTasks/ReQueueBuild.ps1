$token = "$(System.AccessToken)" #https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops&tabs=preview-page

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

function InvokePostRequest ($GetUrl, $body)
{    
    return Invoke-RestMethod -Uri $GetUrl -Method Post -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} #-Body $body
}

$restGetBuildLogs

$buildLogs = InvokeGetRequest $restGetBuildLogs

foreach ($buildLog in $buildLogs.value)
{
    $buildRes = InvokeGetRequest $buildLog.url    

    if ($buildRes.Contains("The operation could not continue because the target database was modified after schema comparison was completed"))
    {
        Write-Host "Needs to restart"

        $restReRunBuild

        $result = InvokePostRequest $restReRunBuild ""

        $result
    }
}
