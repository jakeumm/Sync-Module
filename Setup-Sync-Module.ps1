. (Join-Path $PSScriptRoot 'config.ps1')

$BackupDir = $script:Config.BackupDir

if (!(Test-Path $BackupDir)){
    Write-Host "$BackupDir does not exist - Read the readme for setup instructions" -ForegroundColor Yellow
    return
}

# Create the backup folder structure
$BackupFolders = @(
    (Join-Path $script:Config.EdgeDirBackup $script:Config.EdgeProfile)
    $script:Config.ModulesBackup
    (Split-Path $script:Config.PSProfileBackup)
    $script:Config.PSProfileArchiveDir
    $script:Config.SSHDirBackup
)
foreach ($Folder in $BackupFolders) {
    if (!(Test-Path $Folder)) {
        New-Item $Folder -ItemType Directory -Force | Out-Null
        Write-Host "Created $Folder" -ForegroundColor Green
    }
}

# Install the module for the current user
$ModuleDir = Join-Path $script:Config.ModulesLocal 'Sync-Module'
New-Item $ModuleDir -ItemType Directory -Force | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'Sync-Module.psm1'), (Join-Path $PSScriptRoot 'config.ps1') $ModuleDir -Force
Write-Host "Installed Sync-Module to $ModuleDir" -ForegroundColor Green
Write-Host "Run 'Import-Module Sync-Module' to load it" -ForegroundColor Yellow
Write-Host "Then run 'Backup-All' to create the initial backup (recommended)" -ForegroundColor Yellow
