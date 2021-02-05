$user = ""
$token = "<pat>" #https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops&tabs=preview-page
$teamProject = "team_project_name"
$orgUrl = "https://dev.azure.com/<org>"
$sourceQueryFolder = "Shared Queries/Change Management"
$targetLocalFolder = "c:/temp/Change Management Queries"

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$token)))

$queriesUrl = "$orgUrl/$teamProject/_apis/wit/queries/$sourceQueryFolder"+"?`$depth=1&`$expand=all&api-version=5.0"

function InvokeGetRequest ($GetUrl)
{    
    return Invoke-RestMethod -Uri $GetUrl -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}    
}

$listQueriesUrl

$resQuries = InvokeGetRequest $queriesUrl

if (![System.IO.Directory]::Exists($targetLocalFolder))
{
    New-Item -Path $targetLocalFolder -ItemType "directory"
}

if ($resQuries.isFolder -and $resQuries.hasChildren)
{
    foreach($item in $resQuries.children)
    {
        if (!$item.isFolder)
        {            
            $queryJson = "{`"name`":`"{queryname}`", `"wiql`":`"{querywiql}`"}"

            $queryJson = $queryJson -replace "{queryname}", $item.name
            $queryJson = $queryJson -replace "{querywiql}", $item.wiql

            $filepath = "$targetLocalFolder/" + $item.name

            Set-Content -Path $filepath -Value $queryJson
        }
    }
}