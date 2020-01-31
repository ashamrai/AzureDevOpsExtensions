$targetfolder = "$(Build.StagingDirectory)" + "/"

function CopyFiles{
    param( [string]$source )

    $target = $targetfolder + $source

    New-Item -Force $target
    copy-item $source $target -Force
}

$last_tag = git describe --tags --abbrev=0 --match "[0-9]*"
$changes = git diff --name-only --relative --diff-filter AMR $last_tag HEAD .

if ($changes -is [string]){ CopyFiles $changes }
else
{
    if ($changes -is [array])
    {       
        foreach ($change in $changes){ CopyFiles $change }
    }
}
