$targetfolder = "$(Build.StagingDirectory)" + "/"

function CopyFiles{
    param( [string]$source )

    $target = $targetfolder + $source

    New-Item -Force $target
    copy-item $source $target -Force
}

$changes = git diff --name-only --relative --diff-filter AMR HEAD^ HEAD .

if ($changes -is [string]){ CopyFiles $changes }
else
{
    if ($changes -is [array])
    {       
        foreach ($change in $changes){ CopyFiles $change }
    }
}


 