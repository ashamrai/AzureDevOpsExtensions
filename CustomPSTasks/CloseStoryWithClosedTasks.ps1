$user = ""
$token = $env:SYSTEM_ACCESSTOKEN

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$token)))
$orgUrl = $env:SYSTEM_COLLECTIONURI
$teamProject = "$env:SYSTEM_TEAMPROJECT"

$wiqlGetActiveStories = "SELECT [System.Id] FROM WorkItemLinks WHERE ([Source].[System.TeamProject] = '$teamProject' AND [Source].[System.WorkItemType] = 'User story' AND [Source].[System.State] = 'Active' AND [Source].[System.AreaPath] Under 'BEES - Europe\\Europe - BEES Customer') And ([System.Links.LinkType] = 'System.LinkTypes.Hierarchy-Forward') And ([Target].[System.WorkItemType] = 'Task' AND [Target].[System.State] = 'Closed') ORDER BY [System.Id] mode(MustContain)"
$wiqlStoryClosedTasks = "SELECT[System.Id] FROM WorkItemLinks WHERE([Source].[System.TeamProject] = '$teamProject' AND [Source].[System.Id] = {Parent_ID}) And([System.Links.LinkType] = 'System.LinkTypes.Hierarchy-Forward') And ([Target].[System.WorkItemType] = 'Task' AND ([Target].[System.State] = 'Closed' OR [Target].[System.State] = 'Removed')) ORDER BY [System.Id] mode(MustContain)"
$wiqlStoryAllTasks = "SELECT[System.Id] FROM WorkItemLinks WHERE([Source].[System.TeamProject] = '$teamProject' AND [Source].[System.Id] = {Parent_ID}) And ([System.Links.LinkType] = 'System.LinkTypes.Hierarchy-Forward') And ([Target].[System.WorkItemType] = 'Task') ORDER BY [System.Id] mode(MustContain)"

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

function GetLinkedWICount([string] $wiqlQueryText, [string] $poarentId)
{
    $wiCount = 0
    $queryBody = "{`"query`": `"{querytext}`"}" -replace "{querytext}", $wiqlQueryText

    $result = InvokePostRequestWiql $restQueryWorkItem $queryBody 

    if ($result.workItemRelations.Count -gt 0)
    {
        foreach($relation in $result.workItemRelations)
        {
            if ($null -ne $relation.source)
            {
                $wiCount++
            }
        }
    }

    return $wiCount
}

Write-Host "Close stories with closed tasks"
$activeStories = GetStories $wiqlGetActiveStories

$activeStories.Count

if ($activeStories.Count -gt 0)
{
    foreach ($storyId in $activeStories)
    {
        $queryText = $wiqlStoryClosedTasks -replace "{Parent_ID}", $storyId
        $closedTasks = GetLinkedWICount $queryText
        $queryText = $wiqlStoryAllTasks -replace "{Parent_ID}", $storyId
        $allTasks = GetLinkedWICount $queryText

        Write-Host "$storyId -> $closedTasks : $allTasks"

        if ($closedTasks -eq $allTasks)
        {
            $newStateText = $updateState -replace "{new_state}", "Closed"
            $wiUpdateUrl = $restApiUpdateWorkItem -replace "{id}", $storyId

            $updatedWi = InvokePatchRequest $wiUpdateUrl $newStateText                    
            $updatedWi
        }
    }
}
