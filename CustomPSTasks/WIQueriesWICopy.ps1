$user = ""
$token = "<pat>" #https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops&tabs=preview-page
$teamProjectSource = "source_team_project_name"
$teamProjectTarget = "target_team_project_name"
$orgUrl = "https://dev.azure.com/<org>"
$sourceQueryFolder = "Shared Queries/Change Management"
$targetQueryFolder = "Shared Queries/Change Management" #should exist

$queryObject = [PSCustomObject]@{
    name = $null
    wiql = $null
    columns = $null
    sortColumns = $null
}

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$token)))

$queriesPostUrl = "$orgUrl/$teamProjectTarget/_apis/wit/queries/$targetQueryFolder"+"?api-version=5.0"
$queriesGettUrl = "$orgUrl/$teamProjectSource/_apis/wit/queries/$sourceQueryFolder"+"?`$depth=1&`$expand=all&api-version=5.0"

function InvokeGetRequest ($GetUrl)
{    
    return Invoke-RestMethod -Uri $GetUrl -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}    
}

function InvokePostRequest ($PostUrl, $body)
{   
    return Invoke-RestMethod -Uri $PostUrl -Method Post -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}  -Body $body
}

$resQuries = InvokeGetRequest $queriesGettUrl

if ($resQuries.isFolder -and $resQuries.hasChildren)
{
    foreach($item in $resQuries.children)
    {
        if (!$item.isFolder)
        {   
            $queryObject.name = $item.name 
            $queryObject.wiql = $item.wiql
            $queryObject.columns = $item.columns
            $queryObject.sortcolumns = $item.sortcolumns
            
            $wiqlbody = ConvertTo-Json $queryObject -Depth 10

            InvokePostRequest $queriesPostUrl $wiqlBody
        }
    }
}
