$user = ""
#$token = $env:SYSTEM_ACCESSTOKEN #use this in a build pieline
$token = "<PAT>"

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$token)))
#$orgUrl = $env:SYSTEM_COLLECTIONURI #use this in a build pieline
$orgUrl = "https://dev.azure.com/<org>"
#$teamProject = $env:SYSTEM_TEAMPROJECT #use this in a build pieline
$teamProject = "<team_project>"
#$repoName = $env:BUILD_REPOSITORY_NAME #use this in a build pieline
$repoName = "<git_repo_name>"

$removeWithAhead = $false # update to $true to remove branches with not delivered commits

$restApiGetTags = "$orgUrl/$teamProject/_apis/git/repositories/$repoName/refs?filter=tags/&api-version=6.1-preview.1"
$restApiGetHeads = "$orgUrl/$teamProject/_apis/git/repositories/$repoName/refs?filter=heads/&api-version=6.1-preview.1"
$restApiGetAnonotatedTag = "$orgUrl/$teamProject/_apis/git/repositories/$repoName/annotatedtags/{objectId}?api-version=6.0-preview.1"
$restApiGetCommit = "$orgUrl/$teamProject/_apis/git/repositories/$repoName/commits/{commitId}?api-version=6.1-preview.1"
$restApiGetDiff = "$orgUrl/$teamProject/_apis/git/repositories/$repoName/diffs/commits?baseVersion=master&targetVersion={branchname}&api-version=6.1-preview.1"
$restApiGetPolicies = "$orgUrl/$teamProject/_apis/git/policy/configurations?repositoryId={repoId}&refName={refName}&api-version=6.1-preview.1"
$restApiUpdateRef = "$orgUrl/$teamProject/_apis/git/repositories/$repoName/refs?api-version=6.0"
$restApiGetRepo = "$orgUrl/$teamProject/_apis/git/repositories/$repoName"+"?api-version=5.0"

$removeItemBodyTemplate = "[{`"name`": `"{refName}`",`"oldObjectId`": `"{refObjectId}`",`"newObjectId`": `"0000000000000000000000000000000000000000`"}]"

function InvokeGetRequest ($GetUrl)
{    
    return Invoke-RestMethod -Uri $GetUrl -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}    
}

function InvokePostRequest ($PostUrl, $body)
{   
    return Invoke-RestMethod -Uri $PostUrl -Method Post -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}  -Body $body
}

function RemoveRepoItem([string] $refPath, [string] $refObjectId)
{
    #Remove a branch or tag fromthe git repository
    
    try {
        #remove ref from the repo
        $removeItemBody = $removeItemBodyTemplate -replace "{refName}", $refPath
        $removeItemBody = $removeItemBody -replace "{refObjectId}", $refObjectId

        $removedItem = InvokePostRequest $restApiUpdateRef $removeItemBody

        if ($removedItem.value.Count -gt 0)
        {
            Write-Host $removedItem.value[0]
        }
    }
    catch {
        Write-Host "Error: " $Error[0].ErrorDetails.Message        
    }    
    
}

function RemoveTags
{
    $dtNow = Get-Date
    #Set the date to compare
    $dtFilter = $dtNow.AddDays(-180)

    #Get all tags
    $tags = InvokeGetRequest $restApiGetTags

    Write-Host "Tags count" $tags.count

    foreach ($tag in $tags.value)
    {
        $itscmt = 0
        $atag = $null
        $tagInfo = ""

        Write-Host "Tag" $tag.name

        #Try to get tag information. If the request fails then get commit information (that`s a build tag).
        try {            
            $atagurl = $restApiGetAnonotatedTag.Replace("{objectId}", $tag.objectId)

            $atag = InvokeGetRequest $atagurl              
        }
        catch {
            if ($Error[0].ErrorDetails.Message -like "*resolved to a Commit*")
            {
                $cmturl =  $restApiGetCommit.Replace("{commitId}", $tag.objectId)
                $cmt = InvokeGetRequest $cmturl
                $itscmt = 1
            }
        }      

        #Remove "refs/tags/" from the name to use in the report
        $tagShortName = $tag.name.Replace("refs/tags/", "")

        if ($itscmt -eq 1)
        {            
            $tagInfo = $tagShortName + " : " + $cmt.committer.date + " : " + $cmt.committer.name + " : " + $tag.objectId
            if ($null -eq $cmt.committer.date)
            {
                Write-Host "Commit date is null:" $cmt
                continue
            }
            $tagDate = [DateTime] $cmt.committer.date
        }
        else {        
            $tagInfo = $tagShortName + " : " + $atag.taggedBy.date + " : " + $atag.taggedBy.name + " : " + $atag.taggedObject.objectId         
            if ($null -eq $atag.taggedBy.date)
            {
                Write-Host "Atag date is null:" $atag
                continue
            }
            $tagDate = [DateTime] $atag.taggedBy.date
        }
        
        if ($dtFilter -gt $tagDate)
        {
            Write-Host "Remove $tagInfo"

            RemoveRepoItem $tag.name $tag.objectId
        }

    }
}

function ReplaceSpecialCharacters([string] $itemName)
{
    #replace special characters for url

    $itemNameUrl = $itemName.Replace('$', '%24') 
    $itemNameUrl = $itemNameUrl.Replace('&', '%26') 
    $itemNameUrl = $itemNameUrl.Replace('+', '%2B') 
    $itemNameUrl = $itemNameUrl.Replace(',', '%2C') 
    $itemNameUrl = $itemNameUrl.Replace(':', '%3A') 
    $itemNameUrl = $itemNameUrl.Replace(';', '%3B') 
    $itemNameUrl = $itemNameUrl.Replace('=', '%3D') 
    $itemNameUrl = $itemNameUrl.Replace('?', '%3F') 
    $itemNameUrl = $itemNameUrl.Replace('@', '%40') 

    return $itemNameUrl
}

function RemoveBranches
{
    $dtNow = Get-Date
    #Set the date to compare
    $dtFilter = $dtNow.AddDays(-180)

    #Get all branches
    $branches = InvokeGetRequest $restApiGetHeads

    Write-Host "Branches count" $branches.count

    Write-Host $branches

    foreach ($branch in $branches.value)
    {
        #The default remove status
        $removeStatus = "YES"
        
        #Get the last commit info
        $cmturl =  $restApiGetCommit.Replace("{commitId}", $branch.objectId)
        $cmt = InvokeGetRequest $cmturl
           
        Write-Host "$i BRANCH" $branch.name $cmt.committer.date $cmt.committer.name
        $branchDate = [DateTime] $cmt.committer.date

        #Process a branch to the resulting list if the last commit date in our scope
        if ($dtFilter -gt $branchDate)
        {            
            Write-Host "Check branch" $branch.name
            $branchShortName = $branch.name.Replace("refs/heads/", "")

            if ($true -eq $branch.isLocked)            
            {
                #A branch is locked - do not remove
                $removeStatus = "LOCKED"
            }
            else {
                #Get branch policies
                $branchPUrl = $restApiGetPolicies -replace "{refName}", $branch.name
                
                $branchPolicies = InvokeGetRequest $branchPUrl

                if ($branchPolicies.Count -gt 0)
                {
                    #A branch contains policies - do not remove
                    $removeStatus = "POLICIES"
                }
            }

            if ($removeStatus -eq "YES" -and $removeWithAhead -eq $false)
            {
                #Get behainf/ahead to master
                $branchShortNameUrl = ReplaceSpecialCharacters $branchShortName
                $diffUrl = $restApiGetDiff.Replace("{branchname}", $branchShortNameUrl) 
                $diffRes = InvokeGetRequest $diffUrl            
                
                if ($diffRes.aheadCount -gt 0)
                {
                    $removeStatus = "AHEAD " + $diffRes.aheadCount
                }
            }

            if ($removeStatus -eq "YES")
            {
                Write-Host "Remove $branchShortName"

                RemoveRepoItem $branch.name $branch.objectId                
            }
            else {
                Write-Host "Can not remove branch:" $removeStatus
            }            

        }
    }
}

#get the repo id to use in the get policies request
$repoInfo = InvokeGetRequest $restApiGetRepo
$restApiGetPolicies = $restApiGetPolicies -replace "{repoId}", $repoInfo.id

RemoveBranches

RemoveTags
