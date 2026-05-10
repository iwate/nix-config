function set-pwd {
    $env:pwd = $PWD.Path
}

function cd-ls {
    param($path)
    try {
        set-location $path -erroraction 'stop'
        ls
        set-pwd
    }
    catch {"$_"}
}

filter Get-ShortcutProperty() {
    $sh  = new-object -comobject WScript.Shell
    return $sh.CreateShortcut($_)
}

function Move-Location {
    param(
        [Parameter(Mandatory = $true)]
        $path
    )
    If (((Resolve-Path $path).Path).EndsWith(".lnk")) {
        $ShortcutPath = Get-ChildItem $path | Get-ShortcutProperty
        If ($ShortcutPath.WorkingDirectory) {
            cd-ls $ShortcutPath.WorkingDirectory
        } else {
            cd-ls $ShortcutPath.TargetPath
        }
    } else {
        cd-ls $path
    }
}

function Listen-SRT {
    bash ~/nix-config/home-manager/scripts/listen-srt.sh
}

function Connect-RDP {
    bash ~/nix-config/home-manager/scripts/connect-work-rdp.sh
}

Remove-Item alias:cd
Set-Alias cd Move-Location

~/.local/bin/oh-my-posh --init --shell pwsh | Invoke-Expression

set-pwd

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8