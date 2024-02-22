$user = ""
$token = "<pat>" 

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$token)))

$org = "<org>"
$project = "<team_project>"
$repo = "<repo_name>"

$localfilepath = "<filepath>"
$devopsfilepath = "/<path_to_repo_file>"
$fileurl = "https://dev.azure.com/$org/$project/_apis/git/repositories/$repo/items?scopePath=$devopsfilepath&download=true&api-version=7.2-preview.1"

function InvokeDownloadRequest ($GetUrl, $filepath)
{   
    return Invoke-RestMethod -Uri $GetUrl -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -OutFile $filepath
}

InvokeDownloadRequest $fileurl $localfilepath
