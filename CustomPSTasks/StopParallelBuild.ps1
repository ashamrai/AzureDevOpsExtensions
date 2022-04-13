$user = ""
$token = "$(System.AccessToken)"
$buildDef = "$(System.DefinitionId)"
$branchName = "$(Build.SourceBranch)"
$teamProject = "$(System.TeamProject)"
$orgUrl = "$(System.CollectionUri)"
$buildId = $(Build.BuildId) -as [int]

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$token)))

$uriGetActiveBuilds = "$orgUrl/$teamProject/_apis/build/builds?definitions=$buildDef&statusFilter=inProgress&branchName=$branchName&api-version=5.1"

# use this for any branch: 
# $uriGetActiveBuilds = "$orgUrl/$teamProject/_apis/build/builds?definitions=$buildDef&statusFilter=inProgress&api-version=5.1"

$resultStatus = Invoke-RestMethod -Uri $uriGetActiveBuilds -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}


if ($resultStatus.count -gt 0)
{
    foreach ($build in $resultStatus.value)
    {
        $bid = $build.id -as [int]
        if ($buildId -gt $bid) #if exists a lower value of the build id, the current build should be stoped
        {
            exit 1 
        }
    }
}
