function Write-CoProgress {
    # Central progress output. In the Windows PowerShell child process (PS7 bridge) progress is written
    # to stdout as a marker line and displayed by the parent process via Write-Progress.
    param(
        [string]$Activity,
        [string]$Status = ' ',
        [int]$Percent = -1,
        [switch]$Completed
    )
    if ($env:SILENTCLICKONCE_BRIDGE -eq '1') {
        $msg = ConvertTo-Json -Compress -InputObject @{
            Activity  = $Activity
            Status    = $Status
            Percent   = $Percent
            Completed = $Completed.IsPresent
        }
        [Console]::Out.WriteLine("##CO-PROGRESS $msg")
        return
    }
    if ($Completed) {
        Write-Progress -Activity $Activity -Completed
        return
    }
    $p = @{ Activity = $Activity; Status = $Status }
    if ($Percent -ge 0) { $p.PercentComplete = [Math]::Min($Percent, 100) }
    Write-Progress @p
}
