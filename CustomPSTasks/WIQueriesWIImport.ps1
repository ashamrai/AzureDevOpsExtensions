$user = ""
$token = "<pat>" #https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops&tabs=preview-page
$teamProject = "team_project_name"
$orgUrl = "https://dev.azure.com/<org>"
$sourceLocalFolder = "c:/temp/Change Management Queries"
$targetQueryFolder = "Shared Queries/Change Management Imported" #should exist

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$token)))

$queriesUrl = "$orgUrl/$teamProject/_apis/wit/queries/$targetQueryFolder"+"?api-version=5.0"

function InvokePostRequest ($PostUrl, $body)
{   
    return Invoke-RestMethod -Uri $PostUrl -Method Post -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}  -Body $body
}

$files = Get-ChildItem -File -Path $sourceLocalFolder

foreach($wiqlfile in $files)
{
    $wiqlBody = Get-Content $wiqlfile

    InvokePostRequest $queriesUrl $wiqlBody
}
