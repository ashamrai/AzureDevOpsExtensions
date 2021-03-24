$user = ""
$token = "<pat>"

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$token)))
$orgUrl = "https://dev.azure.com/<org_name>"
$teamProject = "<team_project_name>"
$wikiRepoName = "<wiki_name>.wiki"
$wikiContentTemplate = "{`"content`": `"{content}`"}"

$restApiUpdateWikiPut = "$orgUrl/$teamProject/_apis/wiki/wikis/$wikiRepoName/pages?path={path}&api-version=6.1-preview.1"

function InvokeGetRequest ($GetUrl)
{    
    return Invoke-RestMethod -Uri $GetUrl -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}    
}

function InvokeGetETag ($GetUrl)
{   
    $Headers = $null
    Invoke-RestMethod -Uri $GetUrl -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -ResponseHeadersVariable 'Headers'
    return $Headers["ETag"]
}

function InvokePutRequest ($PutUrl, $body, $eTag)
{   
    return Invoke-RestMethod -Uri $PutUrl -Method Put -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo);"If-Match"="$eTag"}  -Body $body    
}


function UpdateWiki([string] $wkPagePath, [string] $wikiContent)
{
    $ETag = $null
    $updateUrl = $restApiUpdateWikiPut.Replace("{path}", $wkPagePath)

    #Check an existing wiki page
    $wikiPage = InvokeGetRequest $updateUrl 

    if ([string]::IsNullOrEmpty($wikiPage.path))
    {
        Write-Host "Cant not find the page id" $wkPageId
    }
    else 
    {
        #Get Etag that is used in a post request
        $eTagRaw = InvokeGetETag $updateUrl 
    
        $ETag = $eTagRaw -join ""
    }
    
    try {
        #Update a wiki content
        $wikiContentUpdate = $wikiContentTemplate.Replace("{content}", $wikiContent)

        InvokePutRequest $updateUrl $wikiContentUpdate $eTag

    }
    catch {
        Write-Host "Error"
        Write-Host $Error[0]
    }    
}


UpdateWiki "MyWikiPage.md" "mycontent" 
