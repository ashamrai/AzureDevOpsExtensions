$user = ""
#for a build pipeline
#$token = $env:SYSTEM_ACCESSTOKEN
$token = '<pat>'

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$token)))
#for a build pipeline
#$orgUrl = $env:SYSTEM_COLLECTIONURI
$orgUrl = "https://dev.azure.com/<org>"
##for a build pipeline
#$teamProject = $env:SYSTEM_TEAMPROJECT
$teamProject = "<Team Project name>"

$restApiGetBuildDefs = "$orgUrl/$teamProject/_apis/build/definitions?api-version=6.0"
$restApiGetBuilds = "$orgUrl/$teamProject/_apis/build/builds?`$top=1&definitions={definitions}&api-version=6.0"

function InvokeGetRequest ($GetUrl)
{    
    return Invoke-RestMethod -Uri $GetUrl -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}    
}

function GetBuildDefinitions
{
    $dtNow = Get-Date

    $dtFilter = $dtNow.AddDays(-180)

    #Get all build definitions
    $buildDefs = InvokeGetRequest $restApiGetBuildDefs

    foreach ($buildDef in $buildDefs.value)
    {
        #Write-Host $buildDef.id $buildDef.name

        #Get the last build of a build definition
        $buildlistUrl = $restApiGetBuilds -replace "{definitions}", $buildDef.id

        $builds = InvokeGetRequest $buildlistUrl

        if ($builds.count -gt 0)
        {
            $queueDate = [DateTime] $builds.value[0].queueTime
        
            if ($dtFilter -gt $queueDate)
            {
                Write-Host "|  $($buildDef.id) | $($buildDef.name) | $($buildDef.path) | $queueDate  | "
            }
        }
        else {
            Write-Host "| $($buildDef.id) | $($buildDef.name) | $($buildDef.path) | No runs | "
        }
    }
}


GetBuildDefinitions
