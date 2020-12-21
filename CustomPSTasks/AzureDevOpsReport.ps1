$user = ""
$token = "<PAT>" #https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops&tabs=preview-page

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$token)))
$orgUrl = "https://dev.azure.com/<org>"
$teamProject = "<team_project>"
$repoName = "<git_repo_name>"

$restApiGetTags = "$orgUrl/$teamProject/_apis/git/repositories/$repoName/refs?filter=tags/&api-version=6.1-preview.1"
$restApiGetHeads = "$orgUrl/$teamProject/_apis/git/repositories/$repoName/refs?filter=heads/&api-version=6.1-preview.1"
$restApiGetAnonotatedTag = "$orgUrl/$teamProject/_apis/git/repositories/$repoName/annotatedtags/{objectId}?api-version=6.0-preview.1"
$restApiGetCommit = "$orgUrl/$teamProject/_apis/git/repositories/$repoName/commits/{commitId}?api-version=6.1-preview.1"
$restApiGetDiff = "$orgUrl/$teamProject/_apis/git/repositories/$repoName/diffs/commits?baseVersion=master&targetVersion={branchname}&api-version=6.1-preview.1"
$restApiGetPRs = "$orgUrl/$teamProject/_apis/git/repositories/$repoName/pullrequests?searchCriteria.status=active&api-version=6.1-preview.1"
$restApiGetBuildDefs = "$orgUrl/$teamProject/_apis/build/definitions?api-version=6.0"
$restApiGetBuilds = "$orgUrl/$teamProject/_apis/build/builds?`$top=1&definitions={definitions}&api-version=6.0"
$restApiGetReleaseDefs = "$orgUrl/$teamProject/_apis/release/definitions?api-version=6.0" -replace "dev.azure.com", "vsrm.dev.azure.com"
$restApiGetReleases = "$orgUrl/$teamProject/_apis/release/releases?`$top=1&definitionId={definitionId}&api-version=6.0" -replace "dev.azure.com", "vsrm.dev.azure.com"

function InvokeGetRequest ($GetUrl)
{    
    return Invoke-RestMethod -Uri $GetUrl -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}    
}

function GetTags
{
    #The dictionary with a list of resulting strings with tags. The dictionary key is the tag name
    $retTags = @{}
    $dtNow = Get-Date
    #Set the date to compare
    $dtFilter = $dtNow.AddDays(-180)

    #Get all tags
    $tags = InvokeGetRequest $restApiGetTags

    foreach ($tag in $tags.value)
    {
        $itscmt = 0
        $atag = $null

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

        $tagInfo = ""

        #Remove "refs/tags/" from the name to use in the report
        $tagShortName = $tag.name.Replace("refs/tags/", "")

        if ($itscmt -eq 1)
        {            
            $tagInfo = $tagShortName + " | " + $cmt.committer.date + " | " + $cmt.committer.name + " | " + $tag.objectId+ " |"
            if ($null -eq $cmt.committer.date)
            {
                continue
            }
            $tagDate = [DateTime] $cmt.committer.date
        }
        else {        
            $tagInfo = $tagShortName + " | " + $atag.taggedBy.date + " | " + $atag.taggedBy.name + " | " + $atag.taggedObject.objectId + " |"            
            if ($null -eq $atag.taggedBy.date)
            {
                continue
            }
            $tagDate = [DateTime] $atag.taggedBy.date
        }

        #Add a tag to the resulting list if its date in our scope
        if ($dtFilter -gt $tagDate)
        {
            $retTags.Add($tag.name, $tagInfo)
        }
    }

    return $retTags
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
function GetBranches
{
    #The dictionary with a list of resulting strings with branches. The dictionary key is the branch name
    $retBranches = @{}
    $dtNow = Get-Date
    #Set the date to compare
    $dtFilter = $dtNow.AddDays(-180)

    #Get all branches
    $branches = InvokeGetRequest $restApiGetHeads

    foreach ($branch in $branches.value)
    {
        #Get the last commit info
        $cmturl =  $restApiGetCommit.Replace("{commitId}", $branch.objectId)
        $cmt = InvokeGetRequest $cmturl
           
        $branchDate = [DateTime] $cmt.committer.date

        #Add a branch to the resulting list if its date in our scope
        if ($dtFilter -gt $branchDate)
        {            
            $branchShortName = $branch.name.Replace("refs/heads/", "")

            #Get behainf/ahead to master
            $branchShortNameUrl = ReplaceSpecialCharacters $branchShortName
            
            $diffUrl = $restApiGetDiff.Replace("{branchname}", $branchShortNameUrl) 
            $diffRes = InvokeGetRequest $diffUrl            
            
            $retBranches.Add($branch.name, $branchShortName + " | " + $cmt.committer.date + " | " + $cmt.committer.name + " | " + $diffRes.behindCount + " | " + $diffRes.aheadCount + " | ")
        }
    }

    return $retBranches
}

function GetPullRequests
{
    #The dictionary with a list of resulting strings with pul requests. The dictionary key is the pull request id
    $retPRs = @{}
    $dtNow = Get-Date
    #Set the date to compare
    $dtFilter = $dtNow.AddDays(-180)

    #Get all pull requests
    $activePRs = InvokeGetRequest $restApiGetPRs

    foreach($pr in $activePRs.value)
    {
        $prDate = [DateTime] $pr.creationDate

        #Add a pull request to the resulting list if its created date in our scope
        if ($dtFilter -gt $prDate)
        {
            $retPRs.Add($pr.pullRequestId, "" + $pr.pullRequestId + " | " + $pr.Title + " | " + $pr.creationDate + " | " + $pr.createdBy.displayName + " | ")
        }
    }

    return $retPRs
}

function GetBuildDefinitions
{
    #The dictionary with a list of resulting strings with build definitions. The dictionary key is the build definition id
    $retBuildDefs = @{}
    $dtNow = Get-Date
    #Set the date to compare
    $dtFilter = $dtNow.AddDays(-180)

    #Get all build definitions
    $buildDefs = InvokeGetRequest $restApiGetBuildDefs

    foreach ($buildDef in $buildDefs.value)
    {
        #Get the last build of a build definition
        $buildlistUrl = $restApiGetBuilds -replace "{definitions}", $buildDef.id

        $builds = InvokeGetRequest $buildlistUrl

        if ($builds.count -gt 0)
        {
            #Add a build definition to the resulting list if its queued date in our scope
            $queueDate = [DateTime] $builds.value[0].queueTime
        
            if ($dtFilter -gt $queueDate)
            {
                $retBuildDefs.Add($buildDef.id, "" + $buildDef.id + " | " + $buildDef.name + " | " + $buildDef.path + " | " + $queueDate + " | ")
            }
        }
        else {
            #A build does not have runs. Add such build to the list.
            $retBuildDefs.Add($buildDef.id, "" + $buildDef.id + " | " + $buildDef.name + " | " + $buildDef.path + " |  | ")
        }
    }

    return $retBuildDefs
}

function GetReleaseDefinitions
{
    #The dictionary with a list of resulting strings with release definitions. The dictionary key is the release definition id
    $retReleaseDefs = @{}
    $dtNow = Get-Date
    #Set the date to compare
    $dtFilter = $dtNow.AddDays(-180)

    #Get all release definitions
    $releaseDefs = InvokeGetRequest $restApiGetReleaseDefs

    foreach ($releaseDef in $releaseDefs.value)
    {
        #Get the last deployment of a relaese definition
        $releaselistUrl = $restApiGetReleases -replace "{definitionId}", $releaseDef.id

        $releases = InvokeGetRequest $releaselistUrl

        if ($releases.count -gt 0)
        {
            #Add a release definition to the resulting list if its deployment date in our scope
            $createDate = [DateTime] $releases.value[0].createdOn
        
            if ($dtFilter -gt $createDate)
            {
                $retReleaseDefs.Add($releaseDef.id, "" + $releaseDef.id + " | " + $releaseDef.name + " | " + $releaseDef.path + " | " + $createDate + " | ")
            }
        }
        else {
            #A release does not have deployments. Add such release definition to the list.
            $retReleaseDefs.Add($releaseDef.id, "" + $releaseDef.id + " | " + $releaseDef.name + " | " + $releaseDef.path + " |  | ")
        }
    }

    return $retReleaseDefs
}

function PrintResults($section, [hashtable] $reportHash)
{
    #Print the report
    $reportHashSorted = @{}
    $repoContent = ""

    if ($reportHash.Count -gt 0)
    {
        if ($section -eq "branches")
        {
            $repoContent = "`n`n# Branches`n"
            $repoContent += "| N | Path | Date | User | Behind | Ahead |`n"
            $repoContent += "|-----------|-----------|-----------:|:-----------:|:-----------:|-----------:|`n"
        }
        if ($section -eq "tags") 
        {
            $repoContent = "`n`n# Tags`n"
            $repoContent += "| N | Name | Date | User | Commit |`n"
            $repoContent += "|-----------|-----------|-----------:|-----------|-----------|`n"    
        }
        if ($section -eq "prs") 
        {
            $repoContent = "`n`n# Pull Requests`n"
            $repoContent += "| N | ID | Name | Date | User |`n"
            $repoContent += "|-----------|-----------|-----------|-----------:|-----------|`n"    
        }
        if ($section -eq "builds") 
        {
            $repoContent = "`n`n# Builds`n"
            $repoContent += "| N | ID | Name | PATH | Last Run |`n"
            $repoContent += "|-----------|-----------|-----------|-----------|-----------:|`n"    
        }

        if ($section -eq "releases") 
        {
            $repoContent = "`n`n# Releases`n"
            $repoContent = "| N | ID | Name | PATH | Last Deploymet |`n"
            $repoContent += "|-----------|-----------|-----------|-----------|-----------:|`n"    
        }        

        #Sort the resulting dictionary by key
        $reportHashSorted = $reportHash.GetEnumerator() | Sort-Object name    

        for($i = 0; $i -lt $reportHashSorted.Count; $i++)
        {
            $tblIndex = $i + 1
            $repoContent += "| $tblIndex | " + $reportHashSorted[$i].Value + "`n"        
        }
    }

    Write-Host $repoContent
}

# #Generate the report for branches
$repoBranches = GetBranches
PrintResults "branches" $repoBranches

#Generate the report for tags
$repoTags = GetTags
PrintResults "tags" $repoTags

#Generate the report for pull requests
$repoPRs = GetPullRequests
PrintResults "prs" $repoPRs

#Generate the report for build definitions
$repoBuildDefs = GetBuildDefinitions
PrintResults "builds" $repoBuildDefs

#Generate the report for release definitions
$repoReleaseDefs = GetReleaseDefinitions
PrintResults "releases" $repoReleaseDefs
