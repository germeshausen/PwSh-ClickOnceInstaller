# PwSh-ClickOnceInstaller (PowerShell module)

[![CI](https://github.com/germeshausen/PwSh-ClickOnceInstaller/actions/workflows/ci.yml/badge.svg)](https://github.com/germeshausen/PwSh-ClickOnceInstaller/actions/workflows/ci.yml)

Silent install and uninstall of [ClickOnce](https://learn.microsoft.com/en-us/visualstudio/deployment/clickonce-security-and-deployment) applications from PowerShell - no dialogs, no user interaction, with a status object and an exit code you can use in deployment tools.

> **Status:** version `0.3.0.0` - *First Public Release - Beta*.

Inspired by the function of [SilentClickOnce.exe](https://github.com/PaaaulZ/SilentClickOnce) (PaaaulZ/SilentClickOnce: *Install ClickOnce without prompting the user or showing anything*). The dialog-free uninstall is based on [Wunder.ClickOnceUninstaller](https://github.com/rongchunzhang/Wunder.ClickOnceUninstaller) (see [Credits](#credits)).

## Why

ClickOnce normally asks the user to press "Install" or "Remove". If you want to roll out an internal ClickOnce application with a login script, Intune, SCCM or a GPO, that prompt is in the way. Microsoft supports custom installers through `InPlaceHostingManager` (see the [walkthrough](https://docs.microsoft.com/en-us/visualstudio/deployment/walkthrough-creating-a-custom-installer-for-a-clickonce-application?view=vs-2019)); this module wraps that approach - and a silent uninstall - in three PowerShell functions.

## Requirements

- Windows (ClickOnce is Windows-only)
- Windows PowerShell 5.1 **or** PowerShell 7 (see [PowerShell 7](#powershell-7))
- Run in the context of the **target user** - ClickOnce installs per user (see [Limitations](#limitations))

## Installation

The module is not published on the PowerShell Gallery yet. Clone the repository and import the module folder:

```powershell
git clone https://github.com/germeshausen/PwSh-ClickOnceInstaller.git
Import-Module .\PwSh-ClickOnceInstaller\src\PwSh-ClickOnceInstaller\PwSh-ClickOnceInstaller.psd1
```

To make it available in every session, copy `src\PwSh-ClickOnceInstaller` to a folder named `PwSh-ClickOnceInstaller` in one of the paths in `$env:PSModulePath` (for example `$HOME\Documents\PowerShell\Modules\PwSh-ClickOnceInstaller`).

## Usage

```powershell
# Install (with progress bar); returns a result object
Install-ClickOnceApplication '\\server\apps\MyApp\MyApp.application'

# Install without any progress output and start the app afterwards
Install-ClickOnceApplication 'https://example.com/MyApp.application' -Silent -Launch

# List installed ClickOnce applications of the current user
Get-ClickOnceApplication

# Uninstall (the -Name parameter supports tab completion)
Uninstall-ClickOnceApplication -Name MyApp

# Preview what an uninstall would delete, without changing anything
Uninstall-ClickOnceApplication -Name MyApp -WhatIf

# Uninstall through the official ClickOnce maintenance dialog instead
Uninstall-ClickOnceApplication -Name MyApp -Method Dialog
```

Use the exit code in scripts and deployment tools:

```powershell
Import-Module .\PwSh-ClickOnceInstaller\src\PwSh-ClickOnceInstaller\PwSh-ClickOnceInstaller.psd1
$r = Install-ClickOnceApplication 'https://example.com/MyApp.application' -Silent
exit $r.ExitCode
```

Help for every function: `Get-Help Install-ClickOnceApplication -Full` (same for the other functions).

### Functions

| Function | Purpose |
|---|---|
| `Install-ClickOnceApplication` | Installs a ClickOnce application from a `.application` URL or UNC path. Parameters: `-Uri`, `-TimeoutSec` (default 300), `-Launch`, `-Silent`. |
| `Uninstall-ClickOnceApplication` | Removes an installed ClickOnce application. Parameters: `-Name` (wildcards allowed, must match one application), `-Method` (`Direct` default, or `Dialog`), `-Force`, `-TimeoutSec` (Dialog only, default 60), `-Silent`, `-WhatIf`/`-Confirm`. |
| `Get-ClickOnceApplication` | Lists installed ClickOnce applications (`Name`, `Publisher`, `Version`, `PublicKeyToken`, `UninstallArguments`, `RegistryKey`, `Key`, shortcut names). |

### Result object and exit codes

`Install-` and `Uninstall-ClickOnceApplication` return a `PSCustomObject` with `Operation`, `Success`, `ExitCode`, `Status` and `Message` (plus `ProductName`, `Version`, `ShortcutAppId`, `LogFilePath` on install, or `Name`, `Method` and - for the Direct method - `PlannedActions` and `Warnings` on uninstall). The exit code is also written to `$LASTEXITCODE`.

| ExitCode | Status | Meaning |
|---:|---|---|
| 0 | `Installed` / `Uninstalled` / `WhatIf` / `Skipped` | Success (`WhatIf`/`Skipped`: nothing was changed) |
| 1 | `Error` | General error |
| 2 | `InvalidUri` | URI is not an absolute http/https/file URI |
| 3 | `ManifestError` / `Cancelled` | Manifest could not be downloaded or read |
| 4 | `RequirementsError` | Application requirements or trust check failed |
| 5 | `DownloadError` / `Cancelled` | Download or installation failed |
| 6 | `Timeout` | Timeout during download/installation, or the maintenance dialog could not be operated (method `Dialog`) |
| 7 | `NotFound` | No installed ClickOnce application matches `-Name` |
| 8 | `UninstallFailed` | The uninstall entry still exists after the uninstall |
| 9 | `Unsupported` | Not running on Windows |
| 10 | `Ambiguous` | `-Name` matches more than one application |
| 11 | `SharedPublisherKey` | Method `Direct`: other installed applications use the same publisher key (use `-Force` or `-Method Dialog`) |

## How it works

### Install

The installation follows Microsoft's custom installer pattern using `System.Deployment.Application.InPlaceHostingManager`:

1. `GetManifestAsync()` downloads the deployment manifest. The result (`ProductName`, `Version`) is used for status output.
2. `AssertApplicationRequirements($true)` checks the requirements and grants application trust without showing the trust dialog. If that overload is not available, the parameterless overload is used.
3. `DownloadApplicationAsync()` downloads and installs the application. `DownloadProgressChanged` drives the `Write-Progress` bar; at 100 % the status switches to *Finalizing application ...* until ClickOnce reports completion.

The manager's asynchronous .NET events are turned into queued PowerShell events with `Register-ObjectEvent` and awaited with `Wait-Event` under one overall deadline (`-TimeoutSec`). All subscriptions and the manager are cleaned up in a `finally` block.

### PowerShell 7

`System.Deployment.dll` is part of the .NET Framework only and does not exist in .NET (PowerShell 7). When `Install-ClickOnceApplication` runs in PowerShell 7 it therefore validates the parameters, then re-invokes itself in `powershell.exe` (Windows PowerShell 5.1) and returns the result:

- parameters are passed to the child process as Base64-encoded JSON via `-EncodedCommand`,
- progress is sent back as `##CO-PROGRESS {json}` lines on stdout and rendered with `Write-Progress` in the parent,
- the result object comes back as the last JSON line, and the child's stdout is read as UTF-8 so messages with umlauts survive.

`Uninstall-ClickOnceApplication` and `Get-ClickOnceApplication` do not need `System.Deployment` and run natively in both versions.

### Uninstall

ClickOnce has no public silent-uninstall API - the official uninstaller always shows a "Maintenance" dialog. The module offers two ways around that:

#### Method `Direct` (default)

Imitates what the ClickOnce uninstaller does, without any window and without an interactive desktop. The approach is a PowerShell port of [Wunder.ClickOnceUninstaller](https://github.com/rongchunzhang/Wunder.ClickOnceUninstaller):

1. `Get-ClickOnceApplication` reads `HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall`, keeps entries whose `UninstallString` calls `dfshim.dll,ShArpMaintain` and extracts the **public key token** and the shortcut names.
2. The ClickOnce component store (`HKCU:\Software\Classes\Software\Microsoft\Windows\CurrentVersion\Deployment\SideBySide\2.0`, keys `Components` and `Marks`) is read. All components whose key contains the application's public key token belong to the application. Their dependencies are removed too - unless a component is not public or another, foreign component still *implies* it (a `Marks` entry), because then another application needs it.
3. From that a **plan** is built and executed in this order:
   - delete the component folders and `manifests\<component>.*` files in `%LOCALAPPDATA%\Apps\2.0\<12 chars>\<12 chars>`,
   - delete the start menu and desktop shortcuts (`*.appref-ms`, support `*.url`) and the shortcut folders if they are empty afterwards,
   - delete the registry keys/values of the removed components (`Components`, `Marks`) and the keys named after the public key token below `PackageMetadata`, `StateManager\Applications`, `StateManager\Families` and `Visibility`,
   - delete the "Apps & features" entry (last, so an interrupted run can simply be repeated).
4. Success is verified by checking that the uninstall entry is gone. Items that could not be deleted (for example files of a running application) are reported as warnings and in the `Warnings` property.

Every planned action goes through `ShouldProcess`, so `-WhatIf` lists exactly what would be deleted.

Compared with the original tool the port additionally: only considers real ClickOnce entries and supports wildcards/unique matching, handles *all* `Apps\2.0` cache folders (the original used the first one), does not fail on missing registry keys or missing shortcut names, reports failures instead of swallowing them, and refuses to run when other applications share the publisher key (see [Limitations](#limitations)).

#### Method `Dialog`

Starts `rundll32.exe dfshim.dll,ShArpMaintain <application identity>`, which opens the official maintenance dialog, and operates it automatically. A small Win32 helper (`src\PwSh-ClickOnceInstaller\Private\CoDialog.cs`, compiled once per session with `Add-Type`) finds the dialog of that process, hides it, selects the **second radio button** (*Remove the application*) and clicks the **default button** (OK) by sending `BM_CLICK`. Controls are identified by class and style, not by caption, so this does not depend on the Windows display language. Success is verified by waiting until the uninstall entry is gone. This method uses ClickOnce's own logic but needs an interactive desktop session.

## Limitations

- **Per user.** ClickOnce applications live in the profile of the installing user. Run the functions in that user's context (logon script, Intune "user" context, ...), not as `SYSTEM`. Installing or removing an application for another user is not supported.
- **Direct uninstall relies on ClickOnce internals** (registry layout of the component store, cache folder structure) that are not documented by Microsoft. The layout has been stable for many Windows versions, but use `-WhatIf` first when you roll this out, and test with your own application.
- **Shared publisher key.** Components are matched by public key token. If several ClickOnce applications are signed with the same certificate, removing one with the original tool would also remove the components of the others. This module stops with exit code 11 in that case; `-Force` overrides it, `-Method Dialog` uses ClickOnce's own logic.
- **Close the application first.** Files of a running application cannot be deleted; they are reported as warnings.
- **Dialog method** relies on the layout of an undocumented dialog (two radio buttons plus a default button). If a future Windows version changes the dialog, the function returns exit code 6. The dialog may be visible for a moment before it is hidden.
- **Trust.** The installation grants application trust without a prompt - only install from sources you trust. Depending on the ClickOnce trust policy and the publisher's certificate, applications can still be rejected (exit code 4).
- Beta: the API (parameter and property names) may still change before 1.0.

## Development

```powershell
./build.ps1 -Task Lint   # PSScriptAnalyzer (settings in PSScriptAnalyzerSettings.psd1)
./build.ps1 -Task Test   # Pester 5
./build.ps1              # both
```

CI (`.github/workflows/ci.yml`) runs the same script on `windows-latest` with PowerShell 7 and Windows PowerShell 5.1.

Source files are UTF-8 with BOM and CRLF line endings (see `.editorconfig`), so Windows PowerShell 5.1 reads them correctly.

### Repository layout

```text
.
+-- .github/workflows/ci.yml            CI: lint + tests (PS 7 and PS 5.1)
+-- src/PwSh-ClickOnceInstaller/
|   +-- PwSh-ClickOnceInstaller.psd1    Module manifest (version, author, exports)
|   +-- PwSh-ClickOnceInstaller.psm1    Loader: dot-sources Private\ and Public\
|   +-- Public/                         One file per exported function
|   |   +-- Install-ClickOnceApplication.ps1
|   |   +-- Uninstall-ClickOnceApplication.ps1
|   |   +-- Get-ClickOnceApplication.ps1
|   +-- Private/                        Internal helpers (not exported)
|       +-- CoDialog.cs                 Win32 helper for the Dialog method
|       +-- Get-CoClickOnceFolder.ps1   Apps\2.0 cache folders
|       +-- Get-CoComponentToRemove.ps1 Which components belong to an application (pure logic)
|       +-- Get-CoSubKeyName.ps1
|       +-- Get-CoUninstallPlan.ps1     Builds the list of delete actions
|       +-- Initialize-CoDialogType.ps1
|       +-- Invoke-CoDialogUninstall.ps1
|       +-- Invoke-CoDirectUninstall.ps1
|       +-- Invoke-CoInWindowsPowerShell.ps1
|       +-- Invoke-CoPlanAction.ps1     Executes one delete action
|       +-- New-CoPlanAction.ps1
|       +-- New-CoResult.ps1
|       +-- Read-CoClickOnceRegistry.ps1
|       +-- Test-CoWindows.ps1
|       +-- Wait-CoEvent.ps1
|       +-- Write-CoProgress.ps1
+-- tests/PwSh-ClickOnceInstaller.Tests.ps1  Pester 5 tests
+-- build.ps1                           Lint / test entry point
+-- PSScriptAnalyzerSettings.psd1
+-- CHANGELOG.md
+-- THIRD-PARTY-NOTICES.md
+-- README.md
```

Adding a function: create `Public\<Verb-Noun>.ps1` with comment-based help, add the name to `FunctionsToExport` in the manifest, add tests, and note it in `CHANGELOG.md`. When releasing, bump `ModuleVersion` in the manifest (the tests check it) and add a changelog entry.

## License

See [LICENSE](LICENSE). Third-party code notices: [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

## Credits

- Author: [Sven Germeshausen](https://github.com/germeshausen)
- Inspired by [PaaaulZ/SilentClickOnce](https://github.com/PaaaulZ/SilentClickOnce)
- The `Direct` uninstall method is a port of the approach of [Wunder.ClickOnceUninstaller](https://github.com/rongchunzhang/Wunder.ClickOnceUninstaller) (MIT, originally by 6 Wunderkinder GmbH)
- Background: Microsoft's [custom installer walkthrough](https://docs.microsoft.com/en-us/visualstudio/deployment/walkthrough-creating-a-custom-installer-for-a-clickonce-application?view=vs-2019)
