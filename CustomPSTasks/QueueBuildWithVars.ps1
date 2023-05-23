$token = "$(System.AccessToken)" 

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$token)))
$orgUrl = "$(System.CollectionUri)"
$teamProject = "$(System.TeamProject)"

$buildDefId = 'TARGET_BUILDDEF_ID'

$restRunBuild = "$orgUrl/$teamProject/_apis/build/builds?api-version=7.1-preview.7"

function InvokePostRequest ($PostUrl, $BuildBody)
{    
    return Invoke-RestMethod -Uri $PostUrl -Method Post -ContentType "application/json" -Body $BuildBody -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}
}

$buildbody = @"
{
"parameters":  "{\"my.var1\":  \"MY_VAR1\", \"my.var2\":  \"MY_VAR2\"}",
"definition":   {"id":  DEF_ID}
}
"@

$buildbody = $buildbody.Replace("DEF_ID", $buildDefId);
$buildbody = $buildbody.Replace("MY_VAR1", "value 1");
$buildbody = $buildbody.Replace("MY_VAR2", "value 2");

$result = InvokePostRequest $restRunBuild $buildbody

$result
