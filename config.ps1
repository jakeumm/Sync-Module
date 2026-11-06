$BackupDir = "E:\temp\Test\"

# PowerShell 7 and Windows PowerShell 5.1 use different user module folders
$ModulesFolder = if ($PSVersionTable.PSEdition -eq 'Core') { 'PowerShell\Modules' } else { 'WindowsPowerShell\Modules' }

$script:Config = @{
    BackupDir = $BackupDir

    # Backup paths for various configurations and data
    EdgeDirBackup = Join-Path $BackupDir "edge\edge-data"
    KnownHostsBackup = Join-Path $BackupDir "ssh\.ssh\known_hosts"
    ModulesBackup = Join-Path $BackupDir "Modules"
    PSProfileBackup = Join-Path $BackupDir "powershell\profile.ps1"
    PSProfileArchiveDir = Join-Path $BackupDir "powershell\archive\profile"
    SSHDirBackup = Join-Path $BackupDir "ssh\.ssh"

    # Local paths for various configurations and data
    EdgeDirLocal = Join-Path $env:USERPROFILE "AppData\Local\Microsoft\Edge\User Data"
    KnownHostsLocal = Join-Path $env:USERPROFILE ".ssh\known_hosts"
    ModulesLocal = Join-Path ([Environment]::GetFolderPath('MyDocuments')) $ModulesFolder
    PSProfileLocal = $PROFILE
    SSHDirLocal  = Join-Path $env:USERPROFILE ".ssh"

    # Edge profile folder and allowlist of files to back up/sync (bookmarks, settings, autofill)
    EdgeProfile = 'Default'
    EdgeFiles = @('Bookmarks', 'Bookmarks.bak', 'Preferences', 'Secure Preferences', 'Web Data')
}