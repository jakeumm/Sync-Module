# Sync-Module

PowerShell module for backing up and restoring personal settings to a shared backup directory, so they can be synced between machines.

| Item | Local path | Backup path |
| --- | --- | --- |
| Edge profile (Default: bookmarks, settings, autofill) | `%LOCALAPPDATA%\Microsoft\Edge\User Data\Default` | `<BackupDir>\edge\edge-data\Default` |
| PowerShell modules | `Documents\PowerShell\Modules` (see notes) | `<BackupDir>\Modules` |
| PowerShell profile | `$PROFILE` | `<BackupDir>\powershell\profile.ps1` |
| SSH directory | `%USERPROFILE%\.ssh` | `<BackupDir>\ssh\.ssh` |
| SSH known_hosts | `%USERPROFILE%\.ssh\known_hosts` | `<BackupDir>\ssh\.ssh\known_hosts` |

## Setup

### 1. Create the backup directory

Create an empty directory for the backups, for example on a network share.

### 2. Update the config

Edit `config.ps1` and set `$BackupDir` to the directory you just created:

```powershell
$BackupDir = "\\server\share\sync"
```

### 3. Run the setup script

```powershell
.\Setup-Sync-Module.ps1
```

This script:

1. Creates the folder structure in `$BackupDir`.
2. Copies `Sync-Module.psm1` and `config.ps1` to `Documents\PowerShell\Modules\Sync-Module\`.

### 4. Import the module

```powershell
Import-Module Sync-Module
```

To load it automatically, add the line above to your `$PROFILE`.

### 5. Run the first backup (recommended)

```powershell
Backup-All
```

This fills the backup directory so the `Sync-*` commands have something to restore. It closes Edge.

## Usage

`Backup-*` commands copy **local → backup**. `Sync-*` commands copy **backup → local**.

| Command | Description |
| --- | --- |
| `Backup-Edge` / `Sync-Edge` | Copy only the allowlisted files from the Default Edge profile: `Bookmarks`, `Bookmarks.bak`, `Preferences`, `Secure Preferences`, `Web Data`. Edit `EdgeFiles` / `EdgeProfile` in `config.ps1` to change this. Never deletes files at the destination. Closes Edge first. |
| `Backup-Modules` / `Sync-Modules` | Copy user-installed PowerShell modules. `Sync-Modules` doesn't delete local modules that aren't in the backup. |
| `Backup-PSProfile` / `Sync-PSProfile` | Copy the PowerShell profile. `Backup-PSProfile` archives the previous backup to `powershell\archive\profile\` with a timestamp. |
| `Backup-SSH` / `Sync-SSH` | Copy the whole `.ssh` directory. |
| `Backup-KnownHost` / `Sync-KnownHost` | Copy only `known_hosts`. |
| `Backup-All` | Run every `Backup-*` command except `Backup-KnownHost` (covered by `Backup-SSH`). Closes Edge. |

## Backup directory layout

```text
<BackupDir>\
├── edge\
│   └── edge-data\
│       └── Default\
├── Modules\
├── powershell\
│   ├── profile.ps1
│   └── archive\
│       └── profile\
└── ssh\
    └── .ssh\
```

## Notes

- **Edge commands force-close Edge.** Save your work first.
- **Edge `Secure Preferences` is tied to each machine**, so Edge may reset some protected settings (startup pages, search engine, extensions) after syncing to another machine.
- **Saved cards in `Web Data` are encrypted per Windows user and machine (DPAPI)**, so they may not decrypt on another machine. Addresses and form entries carry over. Passwords and cookies are not backed up.
- **Older backups mirrored the whole `User Data` folder.** Only `edge\edge-data\Default\` is used now; you can delete everything else under `edge\edge-data\` manually.
- **`Backup-SSH` copies private keys.** Make sure only you can read the backup directory.
- **Module paths depend on the PowerShell edition.** PowerShell 7 uses `Documents\PowerShell\Modules`; Windows PowerShell 5.1 uses `Documents\WindowsPowerShell\Modules`. Run setup and the module commands from the edition you want to sync.
- **Modules loaded in the current session may be locked**, so `Sync-Modules` can fail to overwrite them. Run it from a fresh session.