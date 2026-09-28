function Invoke-CoDirectUninstall {
    # Dialog-free uninstall: imitates the ClickOnce uninstaller by deleting files, shortcuts and registry entries.
    # Approach taken from Wunder.ClickOnceUninstaller (MIT, see THIRD-PARTY-NOTICES.md).
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]$App,
        [switch]$Force,
        [switch]$ShowProgress,
        [string]$Activity
    )

    $data = @{ Name = $App.Name; Method = 'Direct' }

    if (-not $App.PublicKeyToken) {
        return New-CoResult 'Uninstall' 1 'Error' 'The PublicKeyToken could not be determined from the uninstall entry.' $data
    }

    # Components are matched by public key token, so applications signed with the same key would be removed too.
    $others = @(Get-ClickOnceApplication | Where-Object {
            $_.RegistryKey -ne $App.RegistryKey -and $_.PublicKeyToken -eq $App.PublicKeyToken
        })
    if ($others.Count -gt 0 -and -not $Force) {
        $message = 'Other ClickOnce applications use the same publisher key ({0}): {1}. Direct removal could remove their components as well. Use -Force to continue or -Method Dialog.' -f
            $App.PublicKeyToken, (($others | ForEach-Object { $_.Name }) -join ', ')
        return New-CoResult 'Uninstall' 11 'SharedPublisherKey' $message $data
    }

    if ($ShowProgress) { Write-CoProgress -Activity $Activity -Status 'Analyzing the ClickOnce store ...' -Percent 0 }
    $plan    = Get-CoUninstallPlan -App $App -Registry (Read-CoClickOnceRegistry)
    $actions = @($plan.Actions)
    Write-Verbose ('{0} component(s), {1} action(s) planned.' -f @($plan.Components).Count, $actions.Count)

    $warnings = [System.Collections.Generic.List[string]]::new()
    $done     = 0
    foreach ($action in $actions) {
        if ($ShowProgress) {
            Write-CoProgress -Activity $Activity -Status "Removing: $($action.Target)" -Percent ([int](100 * $done / $actions.Count))
        }
        $done++
        if (-not $PSCmdlet.ShouldProcess($action.Target, $action.Description)) { continue }
        try { Invoke-CoPlanAction -Action $action }
        catch {
            $text = "$($action.Target): $($_.Exception.Message)"
            $warnings.Add($text)
            Write-Warning $text
        }
    }

    $data.PlannedActions = $actions.Count
    $data.Warnings       = $warnings.ToArray()

    if ($WhatIfPreference) {
        return New-CoResult 'Uninstall' 0 'WhatIf' "No changes made (-WhatIf). $($actions.Count) action(s) planned." $data
    }
    if (Test-Path -LiteralPath $App.RegistryKey) {
        return New-CoResult 'Uninstall' 8 'UninstallFailed' 'The uninstall entry still exists.' $data
    }
    New-CoResult 'Uninstall' 0 'Uninstalled' "Uninstalled: $($App.Name)" $data
}
