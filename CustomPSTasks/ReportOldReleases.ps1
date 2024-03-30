$user = ""
#for a build pipeline
#$token = $env:SYSTEM_ACCESSTOKEN
$token = 'personal access token'

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$token)))
#for a build pipeline
#$orgUrl = $env:SYSTEM_COLLECTIONURI
$orgUrl = "https://dev.azure.com/<org_name>"
##for a build pipeline
#$teamProject = $env:SYSTEM_TEAMPROJECT
$teamProject = "<TeamProjectName>"

$restApiGetReleaseDefs = "$orgUrl/$teamProject/_apis/release/definitions?api-version=6.0" -replace "dev.azure.com", "vsrm.dev.azure.com"
$restApiGetReleases = "$orgUrl/$teamProject/_apis/release/releases?`$top=1&definitionId={definitionId}&api-version=6.0" -replace "dev.azure.com", "vsrm.dev.azure.com"

function InvokeGetRequest ($GetUrl)
{    
    return Invoke-RestMethod -Uri $GetUrl -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}    
}

function GetReleaseDefinitions
{
    $dtNow = Get-Date

    $dtFilter = $dtNow.AddDays(-180)

    #Get all release definitions
    $releaseDefs = InvokeGetRequest $restApiGetReleaseDefs

    foreach ($releaseDef in $releaseDefs.value)
    {
        $releaselistUrl = $restApiGetReleases -replace "{definitionId}", $releaseDef.id

        $releases = InvokeGetRequest $releaselistUrl

        if ($releases.count -gt 0)
        {            
            $createDate = [DateTime] $releases.value[0].createdOn
        
            if ($dtFilter -gt $createDate)
            {
                Write-Host "| $($releaseDef.id)  |  $($releaseDef.name) | $($releaseDef.path) | $createDate | "
            }
        }
        else {            
            Write-Host "| $($releaseDef.id)  |  $($releaseDef.name) | $($releaseDef.path) | No runs | "
        }
    }
}

#Generate the report for release definitions
GetReleaseDefinitions
