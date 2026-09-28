function Uninstall-ClickOnceApplication {
    <#
    .SYNOPSIS
        Uninstalls a ClickOnce application of the current user without any user interaction.

    .DESCRIPTION
        Looks up the application via Get-ClickOnceApplication and removes it. Two methods are available:

        Direct (default)
            Imitates the ClickOnce uninstaller: deletes the application's files in the ClickOnce cache,
            its start menu/desktop shortcuts, its entries in the ClickOnce component store (registry) and
            the "Apps & features" entry. Components that other applications still depend on are kept.
            No window is shown and no interactive desktop is required. Use -WhatIf to see what would be
            deleted. Components are matched by publisher key: if other installed ClickOnce applications are
            signed with the same key, the function stops (exit code 11) unless -Force is used.

        Dialog
            Starts the official ClickOnce maintenance dialog (dfshim.dll,ShArpMaintain) and operates it
            automatically ("Remove the application" + OK). Needs an interactive desktop session.

        Tab completion for -Name offers the installed applications.

    .PARAMETER Name
        Display name of the application (wildcards allowed, but it must match exactly one application).

    .PARAMETER Method
        Direct (default) or Dialog. See description.

    .PARAMETER TimeoutSec
        Method Dialog only: maximum time in seconds to find and operate the dialog. Default: 60.

    .PARAMETER Force
        Method Direct only: continue even if other installed ClickOnce applications use the same publisher key.

    .PARAMETER Silent
        Suppresses the progress display (Write-Progress).

    .EXAMPLE
        Uninstall-ClickOnceApplication -Name MyApp

    .EXAMPLE
        Uninstall-ClickOnceApplication -Name MyApp -WhatIf

        Shows every folder, file and registry entry that would be deleted, without deleting anything.

    .EXAMPLE
        $r = Uninstall-ClickOnceApplication -Name 'My*' -Silent
        exit $r.ExitCode

    .EXAMPLE
        Uninstall-ClickOnceApplication -Name MyApp -Method Dialog

    .NOTES
        Close the application before uninstalling it; files that are in use cannot be deleted
        (reported as warnings, see the Warnings property of the result).
        The Direct method is based on Wunder.ClickOnceUninstaller (MIT), see THIRD-PARTY-NOTICES.md.

    .OUTPUTS
        PSCustomObject with Operation, Success, ExitCode, Status, Message, Name and Method
        (Direct: also PlannedActions and Warnings). Also sets $LASTEXITCODE.

    .LINK
        Get-ClickOnceApplication
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $w = [WildcardPattern]::Escape($wordToComplete.Trim('"', "'"))
            Get-ClickOnceApplication | Where-Object { $_.Name -like "$w*" } | Sort-Object Name | ForEach-Object {
                $text = if ($_.Name -match '[^\w\.\-]') { "'" + $_.Name.Replace("'", "''") + "'" } else { $_.Name }
                [System.Management.Automation.CompletionResult]::new($text, $_.Name, 'ParameterValue', $_.Name)
            }
        })]
        [string]$Name,
        [ValidateSet('Direct', 'Dialog')][string]$Method = 'Direct',
        [ValidateRange(5, 600)][int]$TimeoutSec = 60,
        [switch]$Force,
        [switch]$Silent
    )

    if (-not (Test-CoWindows)) {
        return New-CoResult 'Uninstall' 9 'Unsupported' 'ClickOnce is only supported on Windows.'
    }
    $apps = @(Get-ClickOnceApplication -Name $Name)
    if ($apps.Count -eq 0) { return New-CoResult 'Uninstall' 7 'NotFound' "No ClickOnce application found: $Name" }
    if ($apps.Count -gt 1) {
        return New-CoResult 'Uninstall' 10 'Ambiguous' ("Name is not unique: " + (($apps.Name) -join ', '))
    }
    $app      = $apps[0]
    $activity = "ClickOnce uninstallation: $($app.Name)"
    $show     = -not $Silent

    try {
        if ($Method -eq 'Dialog') {
            if (-not $PSCmdlet.ShouldProcess($app.Name, 'Uninstall via the ClickOnce maintenance dialog')) {
                return New-CoResult 'Uninstall' 0 'Skipped' 'Skipped (-WhatIf or declined).' @{ Name = $app.Name; Method = $Method }
            }
            Invoke-CoDialogUninstall -App $app -TimeoutSec $TimeoutSec -ShowProgress:$show -Activity $activity
        }
        else {
            Invoke-CoDirectUninstall -App $app -Force:$Force -ShowProgress:$show -Activity $activity -WhatIf:$WhatIfPreference
        }
    }
    finally {
        if ($show) { Write-CoProgress -Activity $activity -Completed }
    }
}
