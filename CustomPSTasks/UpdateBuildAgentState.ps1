$user = ""
$token = "<pat>" #https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops&tabs=preview-page

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$token)))

$org = "<org_name>"
$poolId = <pool_id>
$agentId = <agent_id>

#$requsetBody = '{"id":{agentId},"enabled":false}' #disable agent

$requsetBody = '{"id":{agentId},"status":"offline"}' #switch to offline

$requsetBody = $requsetBody -replace "{agentId}", $agentId

$restApiUpdateAgent = "https://dev.azure.com/$org/_apis/distributedtask/pools/$poolId/agents/$agentId`?api-version=6.0"

$restApiUpdateAgent

function InvokePatchReques ($PatchUrl, $body)
{   
    return Invoke-RestMethod -Uri $PatchUrl -Method Patch -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -Body $body
}

$result = InvokePatchReques $restApiUpdateAgent $requsetBody

Write-Host $result
