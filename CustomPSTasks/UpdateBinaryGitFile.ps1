$user = ""
$token = "<PAT>" #https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops&tabs=preview-page

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$token)))
$orgUrl = "https://dev.azure.com/<org>"
$teamProject = "TestProject"
$repoName = "Repo1"

$localFilePath = '<local_path>/<file_name>.<extension>'
$gitFilePath = '<repo_path>/<file_name>.<extension>'
$gitBranch = "master"

$restApiUpdateFile = "$orgUrl/$teamProject/_apis/git/repositories/$repoName/pushes?api-version=6.1-preview.2"
$restApiGetMasterRef = "$orgUrl/$teamProject/_apis/git/repositories/$repoName/refs?filter=heads/$gitBranch`&api-version=6.1-preview.1"

$fileContentToUpdate = [convert]::ToBase64String((Get-Content -path $localFilePath -Encoding byte))

function InvokeGetRequest ($GetUrl)
{    
    return Invoke-RestMethod -Uri $GetUrl -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}    
}

function InvokePostRequest ($PostUrl, $body)
{   
    return Invoke-RestMethod -Uri $PostUrl -Method Post -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}  -Body $body
}

$updateBody = @"
{
    "refUpdates": [
      {
        "name": "refs/heads/{gitbranchpath}",
        "oldObjectId": "{mainBranchObjectId}"
      }
    ],
    "commits": [
      {
        "comment": "Updates file",
        "changes": [
          {
            "changeType": "edit",
            "item": {
              "path": "{filePathToUpdate}"
            },
            "newContent": {
              "content": "{newFileContentToUpdate}",
              "contentType": "base64encoded"
            }
          }
        ]
      }
    ]
  }
"@

$res = InvokeGetRequest $restApiGetMasterRef

$updateBody = $updateBody.Replace("{gitbranchpath}", $gitBranch);
$updateBody = $updateBody.Replace("{mainBranchObjectId}", $res.value[0].objectId);
$updateBody = $updateBody.Replace("{filePathToUpdate}", $gitFilePath);
$updateBody = $updateBody.Replace("{newFileContentToUpdate}", $fileContentToUpdate);


InvokePostRequest $restApiUpdateFile $updateBody
