$user = ""
$token = $env:SYSTEM_ACCESSTOKEN

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$token)))
$orgUrl = $env:SYSTEM_COLLECTIONURI
$teamProject = "$env:SYSTEM_TEAMPROJECT"

$wiqlGetNewStories = "SELECT [System.Id] FROM WorkItemLinks WHERE ([Source].[System.TeamProject] = '$teamProject' AND [Source].[System.WorkItemType] = 'User story' AND [Source].[System.State] = 'New' AND [Source].[System.AreaPath] Under 'BEES - Europe\\Europe - BEES Customer') And ([System.Links.LinkType] = 'System.LinkTypes.Hierarchy-Forward') And ([Target].[System.WorkItemType] = 'Task' AND [Target].[System.State] = 'Active') ORDER BY [System.Id] mode(MustContain)"

$updateState = "[{`"op`": `"add`", `"path`": `"/fields/System.State`", `"value`": `"{new_state}`"}]"

$restQueryWorkItem = "$orgUrl/$teamProject/_apis/wit/wiql?api-version=6.1-preview.2"
$restApiUpdateWorkItem = "$orgUrl/$teamProject/_apis/wit/workitems/{id}?api-version=6.1-preview.3"

function InvokeGetRequest ($GetUrl)
{    
    return Invoke-RestMethod -Uri $GetUrl -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}    
}

function InvokePostRequestWiql ($PostUrl, $body)
{   
    return Invoke-RestMethod -Uri $PostUrl -Method Post -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}  -Body $body
}

function InvokePatchRequest ($PostUrl, $body)
{    
    return Invoke-RestMethod -Uri $PostUrl -Method Patch -ContentType "application/json-patch+json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}  -Body $body
}

function GetStories([string] $wiqlQueryText)
{
    $retIds = @()
    $queryBody = "{`"query`": `"{querytext}`"}" -replace "{querytext}", $wiqlQueryText

    $result = InvokePostRequestWiql $restQueryWorkItem $queryBody 

    if ($result.workItemRelations.Count -gt 0)
    {
        foreach($relation in $result.workItemRelations)
        {
            if ($null -eq $relation.source)
            {
                $retIds += $relation.target.id
            }
        }
    }

    return $retIds
}

Write-Host "Activate stories with active tasks"
$newStories = GetStories $wiqlGetNewStories
$newStories.Count

if ($newStories.Count -gt 0)
{
    foreach ($storyId in $newStories)
    {
        $newStateText = $updateState -replace "{new_state}", "Active"
        $wiUpdateUrl = $restApiUpdateWorkItem -replace "{id}", $storyId

        $updatedWi = InvokePatchRequest $wiUpdateUrl $newStateText                    
        $updatedWi        
    }
}
