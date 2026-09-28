function Invoke-CoDialogUninstall {
    # Uninstall via the official ClickOnce maintenance dialog (dfshim.dll,ShArpMaintain), operated automatically.
    param(
        [Parameter(Mandatory)]$App,
        [int]$TimeoutSec = 60,
        [switch]$ShowProgress,
        [string]$Activity
    )

    $data = @{ Name = $App.Name; Method = 'Dialog' }
    try {
        Initialize-CoDialogType
        $deadline = [datetime]::UtcNow.AddSeconds($TimeoutSec)
        if ($ShowProgress) { Write-CoProgress -Activity $Activity -Status 'Starting maintenance dialog ...' }
        $proc = Start-Process -FilePath (Join-Path $env:windir 'System32\rundll32.exe') `
            -ArgumentList "dfshim.dll,ShArpMaintain $($App.UninstallArguments)" -PassThru

        $clicked = $false
        while ([datetime]::UtcNow -lt $deadline) {
            if ([CoDialog]::RemoveApplication([uint32]$proc.Id)) { $clicked = $true; break }
            if ($proc.HasExited) { break }
            Start-Sleep -Milliseconds 200
        }
        if (-not $clicked) {
            if (-not $proc.HasExited) { $proc.Kill() }
            return New-CoResult 'Uninstall' 6 'Timeout' 'Maintenance dialog not found or could not be operated.' $data
        }

        # Verify the result: the uninstall entry must disappear
        if ($ShowProgress) { Write-CoProgress -Activity $Activity -Status 'Removing application ...' }
        while ([datetime]::UtcNow -lt $deadline -and (Test-Path -LiteralPath $App.RegistryKey)) {
            Start-Sleep -Milliseconds 300
        }
        if (Test-Path -LiteralPath $App.RegistryKey) {
            return New-CoResult 'Uninstall' 8 'UninstallFailed' 'The uninstall entry still exists.' $data
        }
        New-CoResult 'Uninstall' 0 'Uninstalled' "Uninstalled: $($App.Name)" $data
    }
    catch {
        New-CoResult 'Uninstall' 1 'Error' $_.Exception.Message $data
    }
}
