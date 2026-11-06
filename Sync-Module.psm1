. (Join-Path $PSScriptRoot 'config.ps1')

# Sync-Module: back up personal settings (Edge, PowerShell modules/profile, SSH) to $Config.BackupDir
# and restore them on another machine. Backup-* copies local -> backup, Sync-* copies backup -> local.
# Paths are set in config.ps1. Run 'Get-Command -Module Sync-Module' to list commands.

# Edge Functions
# Copies only the allowlisted files (Config.EdgeFiles) in the Edge profile folder. Never deletes at the destination.
function Copy-EdgeProfileFiles {
    <#
    .SYNOPSIS
    Copies the allowlisted Edge profile files from one folder to another.

    .DESCRIPTION
    Helper used by Backup-Edge and Sync-Edge. Force-closes Edge, then uses robocopy to copy only the
    files listed in $Config.EdgeFiles (config.ps1) from Source to Destination. Warns about
    allowlisted files missing at the source. Never deletes files at the destination.

    .PARAMETER Source
    Edge profile folder to copy from, for example "...\Edge\User Data\Default".

    .PARAMETER Destination
    Folder to copy to. Created if it doesn't exist.

    .OUTPUTS
    System.Boolean. $true if the copy succeeded, $false if Edge couldn't be closed or robocopy failed.

    .EXAMPLE
    Copy-EdgeProfileFiles -Source "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default" -Destination 'E:\Backup\edge\edge-data\Default'

    .NOTES
    Closes all Edge windows without prompting.

    .LINK
    Backup-Edge

    .LINK
    Sync-Edge
    #>

    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination
    )

    # Stop Edge processes before copying so files aren't locked or mid-write
    Get-Process msedge -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 2
    if (Get-Process msedge -ErrorAction SilentlyContinue) {
        Write-Host "Some Edge processes are still running - Stopping..." -ForegroundColor Red
        return $false
    }

    $EdgeFiles = $script:Config.EdgeFiles
    foreach ($File in $EdgeFiles) {
        if (!(Test-Path -LiteralPath (Join-Path $Source $File))) {
            Write-Host "$File not found in $Source - Skipping" -ForegroundColor Yellow
        }
    }

    if (!(Test-Path $Destination)) {New-Item $Destination -ItemType Directory -Force | Out-Null}

    robocopy $Source $Destination @EdgeFiles /R:1 /W:1 /NFL /NDL | Out-Host
    # robocopy exit codes 8+ indicate failure
    if ($LASTEXITCODE -ge 8) {Write-Host "robocopy failed with exit code $LASTEXITCODE" -ForegroundColor Red
        return $false
    }
    return $true
}

function Backup-Edge {
    <#
    .SYNOPSIS
    Backs up Edge bookmarks, settings and autofill to the backup directory.

    .DESCRIPTION
    Copies the allowlisted files ($Config.EdgeFiles: Bookmarks, Bookmarks.bak, Preferences,
    Secure Preferences, Web Data) from the local Edge profile ($Config.EdgeProfile, default "Default")
    to <BackupDir>\edge\edge-data\<EdgeProfile>. Files at the destination are never deleted.

    .EXAMPLE
    Backup-Edge

    .NOTES
    Force-closes Edge. Save your work first.

    .LINK
    Sync-Edge
    #>

    # Set variables for Edge profile directories
    $EdgeProfileBackup = Join-Path $script:Config.EdgeDirBackup $script:Config.EdgeProfile
    $EdgeProfileLocal = Join-Path $script:Config.EdgeDirLocal $script:Config.EdgeProfile

    # Ensure Edge directories exist
    if (!(Test-Path $script:Config.EdgeDirBackup)){Write-Host "$($script:Config.EdgeDirBackup) does not exist - Stopping..." -ForegroundColor Red
        return
    }
    if (!(Test-Path $EdgeProfileLocal)){Write-Host "$EdgeProfileLocal does not exist - Stopping..." -ForegroundColor Red
        return
    }

    # Copy Edge data from local to backup
    Write-Host "Backing up Edge data from $EdgeProfileLocal to $EdgeProfileBackup" -ForegroundColor Yellow
    if (Copy-EdgeProfileFiles -Source $EdgeProfileLocal -Destination $EdgeProfileBackup) {
        Write-Host "Backup of Edge data completed" -ForegroundColor Green
    }
}

function Sync-Edge {
    <#
    .SYNOPSIS
    Restores Edge bookmarks, settings and autofill from the backup directory.

    .DESCRIPTION
    Copies the allowlisted files ($Config.EdgeFiles) from <BackupDir>\edge\edge-data\<EdgeProfile>
    to the local Edge profile. Local files that aren't in the allowlist are left alone.

    .EXAMPLE
    Sync-Edge

    .NOTES
    Force-closes Edge. Save your work first.
    Secure Preferences is tied to each machine, and saved cards in Web Data are encrypted per user and
    machine (DPAPI), so some settings and cards may not carry over to another machine.

    .LINK
    Backup-Edge
    #>

    # Set variables for Edge profile directories
    $EdgeProfileBackup = Join-Path $script:Config.EdgeDirBackup $script:Config.EdgeProfile
    $EdgeProfileLocal = Join-Path $script:Config.EdgeDirLocal $script:Config.EdgeProfile

    # Ensure Edge backup exists
    if (!(Test-Path $EdgeProfileBackup)){Write-Host "$EdgeProfileBackup does not exist - Stopping..." -ForegroundColor Red
        return
    }

    # Copy Edge data from backup to local
    Write-Host "Syncing Edge data from $EdgeProfileBackup to $EdgeProfileLocal" -ForegroundColor Yellow
    if (Copy-EdgeProfileFiles -Source $EdgeProfileBackup -Destination $EdgeProfileLocal) {
        Write-Host "Sync of Edge data completed" -ForegroundColor Green
    }
}

# KnownHosts Functions
function Backup-KnownHost {
    <#
    .SYNOPSIS
    Backs up the SSH known_hosts file.

    .DESCRIPTION
    Copies %USERPROFILE%\.ssh\known_hosts to <BackupDir>\ssh\.ssh\known_hosts, overwriting the
    existing backup. Backup-SSH already covers this file; use this to back up only known_hosts.

    .EXAMPLE
    Backup-KnownHost

    .LINK
    Sync-KnownHost

    .LINK
    Backup-SSH
    #>

    # Set variables for KnownHosts files
    $KnownHostsLocal = $script:Config.KnownHostsLocal
    $KnownHostsBackup = $script:Config.KnownHostsBackup

    # Ensure local file and backup directory exist
    if (!(Test-Path $KnownHostsLocal)){Write-Host "$KnownHostsLocal does not exist - Stopping..." -ForegroundColor Red
        return
    }
    $KnownHostsBackupDir = Split-Path $KnownHostsBackup
    if (!(Test-Path $KnownHostsBackupDir)){Write-Host "$KnownHostsBackupDir does not exist - Stopping..." -ForegroundColor Red
        return
    }

    # Copy KnownHosts from local to backup
    Write-Host "Backing up $KnownHostsLocal to $KnownHostsBackup" -ForegroundColor Yellow
    Copy-Item $KnownHostsLocal $KnownHostsBackup  -Force
    Write-Host "Backup of $KnownHostsLocal completed" -ForegroundColor Green
}

function Sync-KnownHost {
    <#
    .SYNOPSIS
    Restores the SSH known_hosts file from the backup directory.

    .DESCRIPTION
    Copies <BackupDir>\ssh\.ssh\known_hosts to %USERPROFILE%\.ssh\known_hosts, overwriting the local
    file. Creates the local .ssh folder if needed.

    .EXAMPLE
    Sync-KnownHost

    .LINK
    Backup-KnownHost

    .LINK
    Sync-SSH
    #>

    # Set variables for KnownHosts files
    $KnownHostsLocal = $script:Config.KnownHostsLocal
    $KnownHostsBackup = $script:Config.KnownHostsBackup

    # Ensure KnownHosts Backup files exists
    if (!(Test-Path $KnownHostsBackup)){Write-Host "$KnownHostsBackup does not exist - Stopping..." -ForegroundColor Red
        return
    }

    New-Item (Split-Path $KnownHostsLocal) -ItemType Directory -Force | Out-Null

    # Copy KnownHosts from backup to local
    Write-Host "Syncing KnownHosts from $KnownHostsBackup to $KnownHostsLocal" -ForegroundColor Yellow
    Copy-Item $KnownHostsBackup $KnownHostsLocal -Force
    Write-Host "Sync of KnownHosts completed" -ForegroundColor Green
}

# Module Functions
function Backup-Modules {
    <#
    .SYNOPSIS
    Backs up user-installed PowerShell modules.

    .DESCRIPTION
    Mirrors the current user's module folder ($Config.ModulesLocal) to <BackupDir>\Modules with
    robocopy /MIR. Modules removed locally are also removed from the backup.

    .EXAMPLE
    Backup-Modules

    .NOTES
    The module folder depends on the edition: Documents\PowerShell\Modules for PowerShell 7,
    Documents\WindowsPowerShell\Modules for Windows PowerShell 5.1.

    .LINK
    Sync-Modules
    #>

    # Set variables for module directories
    $ModulesLocal = $script:Config.ModulesLocal
    $ModulesBackup = $script:Config.ModulesBackup

    # Ensure module directories exist
    if (!(Test-Path $ModulesLocal)){Write-Host "$ModulesLocal does not exist - Stopping..." -ForegroundColor Red
        return
    }
    if (!(Test-Path $ModulesBackup)){Write-Host "$ModulesBackup does not exist - Stopping..." -ForegroundColor Red
        return
    }

    # Mirror modules from local to backup
    Write-Host "Backing up modules from $ModulesLocal to $ModulesBackup" -ForegroundColor Yellow
    robocopy $ModulesLocal $ModulesBackup /MIR /R:1 /W:1 /NFL /NDL
    if ($LASTEXITCODE -ge 8) {Write-Host "robocopy failed with exit code $LASTEXITCODE" -ForegroundColor Red
        return
    }
    Write-Host "Backup of modules completed" -ForegroundColor Green
}

function Sync-Modules {
    <#
    .SYNOPSIS
    Restores user-installed PowerShell modules from the backup directory.

    .DESCRIPTION
    Copies <BackupDir>\Modules to the current user's module folder ($Config.ModulesLocal) with
    robocopy /E. Modules that exist only on this machine are kept.

    .EXAMPLE
    Sync-Modules

    .NOTES
    Modules loaded in the current session may be locked. Run this from a fresh session.

    .LINK
    Backup-Modules
    #>

    # Set variables for module directories
    $ModulesLocal = $script:Config.ModulesLocal
    $ModulesBackup = $script:Config.ModulesBackup

    # Ensure module directories exist
    if (!(Test-Path $ModulesBackup)){Write-Host "$ModulesBackup does not exist - Stopping..." -ForegroundColor Red
        return
    }
    if (!(Test-Path $ModulesLocal)){New-Item $ModulesLocal -ItemType Directory -Force | Out-Null}

    # /E instead of /MIR so modules installed only on this machine are kept
    Write-Host "Syncing modules from $ModulesBackup to $ModulesLocal" -ForegroundColor Yellow
    robocopy $ModulesBackup $ModulesLocal /E /R:1 /W:1 /NFL /NDL
    if ($LASTEXITCODE -ge 8) {Write-Host "robocopy failed with exit code $LASTEXITCODE" -ForegroundColor Red
        return
    }
    Write-Host "Sync of modules completed" -ForegroundColor Green
}

# PSProfile Functions
function Backup-PSProfile {
    <#
    .SYNOPSIS
    Backs up the PowerShell profile and archives the previous backup.

    .DESCRIPTION
    Copies $PROFILE to <BackupDir>\powershell\profile.ps1. If a backup already exists, it is first
    copied to <BackupDir>\powershell\archive\profile\<yyyy-MM-dd-HHmmss>.ps1.

    .EXAMPLE
    Backup-PSProfile

    .LINK
    Sync-PSProfile
    #>

    # Set variables for PSProfile files
    $PSProfileBackup = $script:Config.PSProfileBackup
    $PSProfileArchiveDir = $script:Config.PSProfileArchiveDir
    $PSProfileArchive = Join-Path $PSProfileArchiveDir "$(Get-Date -Format yyyy-MM-dd-HHmmss).ps1"
    $PSProfileLocal = $PROFILE

    # Ensure local profile and backup directories exist
    if (!(Test-Path $PSProfileLocal)){Write-Host "$PSProfileLocal does not exist - Stopping..." -ForegroundColor Red
        return
    }
    $PSProfileBackupDir = Split-Path $PSProfileBackup
    if (!(Test-Path $PSProfileBackupDir)){Write-Host "$PSProfileBackupDir does not exist - Stopping..." -ForegroundColor Red
        return
    }
    if (!(Test-Path $PSProfileArchiveDir)){Write-Host "$PSProfileArchiveDir does not exist - Stopping..." -ForegroundColor Red
        return
    }

    # Archive the previous backup, if there is one
    if (Test-Path $PSProfileBackup) {
        Write-Host "Archiving $PSProfileBackup to $PSProfileArchive" -ForegroundColor Yellow
        Copy-Item $PSProfileBackup $PSProfileArchive -Force
        if (!(Test-Path $PSProfileArchive)){Write-Host "$PSProfileArchive could not be archived - Stopping..." -ForegroundColor Red
            return
        }
    }

    # Copy PSProfile from local to backup
    Write-Host "Backing up $PSProfileLocal to $PSProfileBackup" -ForegroundColor Yellow
    Copy-Item $PSProfileLocal $PSProfileBackup -Force
    Write-Host "Backup of $PSProfileBackup completed" -ForegroundColor Green
}

function Sync-PSProfile {
    <#
    .SYNOPSIS
    Restores the PowerShell profile from the backup directory.

    .DESCRIPTION
    Copies <BackupDir>\powershell\profile.ps1 to $PROFILE, overwriting the local profile. Creates the
    profile folder if needed. Restart PowerShell or run '. $PROFILE' to load it.

    .EXAMPLE
    Sync-PSProfile

    .LINK
    Backup-PSProfile
    #>

    # Set variables for PSProfile files
    $PSProfileBackup = $script:Config.PSProfileBackup
    $PSProfileLocal = $PROFILE

    if (!(Test-Path $PSProfileBackup)){Write-Host "$PSProfileBackup does not exist - Stopping..." -ForegroundColor Red
        return
    }
    New-Item (Split-Path $PSProfileLocal) -ItemType Directory -Force | Out-Null

    # Copy PSProfile from backup to local
    Write-Host "Syncing PSProfile from $PSProfileBackup to $PSProfileLocal" -ForegroundColor Yellow
    Copy-Item $PSProfileBackup $PSProfileLocal -Force
    Write-Host "Sync of PSProfile completed" -ForegroundColor Green 
}



# SSH Functions
function Backup-SSH {
    <#
    .SYNOPSIS
    Backs up the whole .ssh directory.

    .DESCRIPTION
    Copies everything in %USERPROFILE%\.ssh (keys, config, known_hosts) to <BackupDir>\ssh\.ssh,
    overwriting existing files. Files removed locally are not removed from the backup.

    .EXAMPLE
    Backup-SSH

    .NOTES
    This copies private keys. Make sure only you can read the backup directory.

    .LINK
    Sync-SSH

    .LINK
    Backup-KnownHost
    #>

    # Set variables for SSH directories
    $SSHDirLocal = $script:Config.SSHDirLocal
    $SSHDirBackup = $script:Config.SSHDirBackup

    # Ensure SSH directories exist
    if (!(Test-Path $SSHDirLocal)){Write-Host "$SSHDirLocal does not exist - Stopping..." -ForegroundColor Red
        return
    }
    if (!(Test-Path $SSHDirBackup)){Write-Host "$SSHDirBackup does not exist - Stopping..." -ForegroundColor Red
        return
    }

    # Copy SSH data from local to backup
    Write-Host "Backing up SSH data from $SSHDirLocal to $SSHDirBackup" -ForegroundColor Yellow
    Copy-Item (Join-Path $SSHDirLocal '*') $SSHDirBackup -Recurse -Force
    Write-Host "Backup of SSH data completed" -ForegroundColor Green
}

function Sync-SSH {
    <#
    .SYNOPSIS
    Restores the .ssh directory from the backup directory.

    .DESCRIPTION
    Copies everything in <BackupDir>\ssh\.ssh to %USERPROFILE%\.ssh, overwriting existing files.
    Local files that aren't in the backup are kept.

    .EXAMPLE
    Sync-SSH

    .LINK
    Backup-SSH

    .LINK
    Sync-KnownHost
    #>

    # Set variables for SSH directories
    $SSHDirLocal = $script:Config.SSHDirLocal
    $SSHDirBackup = $script:Config.SSHDirBackup

    # Ensure SSH directories exist
    if (!(Test-Path $SSHDirBackup)){Write-Host "$SSHDirBackup does not exist - Stopping..." -ForegroundColor Red
        return
    }
    if (!(Test-Path $SSHDirLocal)){New-Item $SSHDirLocal -ItemType Directory -Force | Out-Null}

    # Copy SSH data from backup to local
    Write-Host "Syncing SSH data from $SSHDirBackup to $SSHDirLocal" -ForegroundColor Yellow
    Copy-Item (Join-Path $SSHDirBackup '*') $SSHDirLocal -Recurse -Force
    Write-Host "Sync of SSH data completed" -ForegroundColor Green
}

# Run all backups
function Backup-All {
    <#
    .SYNOPSIS
    Runs every backup command.

    .DESCRIPTION
    Runs Backup-Edge, Backup-Modules, Backup-PSProfile and Backup-SSH in order. Backup-KnownHost is
    skipped because Backup-SSH already copies known_hosts.

    .EXAMPLE
    Backup-All

    .NOTES
    Force-closes Edge. Save your work first.

    .LINK
    Backup-Edge

    .LINK
    Backup-Modules

    .LINK
    Backup-PSProfile

    .LINK
    Backup-SSH
    #>

    Backup-Edge
    Backup-Modules
    Backup-PSProfile
    Backup-SSH
}