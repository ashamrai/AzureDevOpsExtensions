$user = ""
$token = '$(System.AccessToken)'

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$token)))
$orgUrl = "$(System.CollectionUri)"
$teamProject = "$(System.TeamProject)"
$repoName = "$(Build.Repository.Name)"
$prId = "$(System.PullRequest.PullRequestId)"
$fileName = "YOU_FILE_NAME.EXT"
$localFilePath = "$(System.DefaultWorkingDirectory)/YOUR_FILE_PATH"
$bodyCommentTemplate = @"
{
  "comments": [
    {
      "parentCommentId": 0,
      "content": "[LINK_NAME](LINK_REF)",
      "commentType": 1
    }
  ],
  "status": 1
}
"@

$restAddAttachment = "$orgUrl/$teamProject/_apis/git/repositories/$repoName/pullRequests/$prId/attachments/$fileName`?api-version=7.1-preview.1"
$restAddComment = "$orgUrl/$teamProject/_apis/git/repositories/$repoName/pullRequests/$prId/threads?api-version=7.1-preview.1"

function InvokePostFileRequest ($PostUrl, $FilePath)
{    
    return Invoke-RestMethod -Uri $PostUrl -Method Post -ContentType "application/octet-stream" -InFile $FilePath -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}
}

function InvokePostRequest ($PostUrl, $PostBody)
{    
    return Invoke-RestMethod -Uri $PostUrl -Method Post -ContentType "application/json" -Body $PostBody -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}
}


$resAttachment = InvokePostFileRequest $restAddAttachment $localFilePath 

$attachmentRef = "[$($resAttachment.displayName)]($($resAttachment.url))"

$attachmentRef

$bodyComment = $bodyCommentTemplate -replace "LINK_NAME", $resAttachment.displayName
$bodyComment = $bodyComment -replace "LINK_REF", $resAttachment.url

InvokePostRequest $restAddComment $bodyComment

