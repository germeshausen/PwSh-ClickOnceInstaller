function Wait-CoEvent {
    # Waits for a queued .NET event (Register-ObjectEvent) until the deadline.
    # Optionally drains download-progress events and reports them via Write-CoProgress.
    param(
        [string]$SourceId,
        [string]$ProgressId,
        [datetime]$Deadline,
        [string]$Activity,
        [switch]$ShowProgress
    )
    while ([datetime]::UtcNow -lt $Deadline) {
        $ev = Wait-Event -SourceIdentifier $SourceId -Timeout 1
        if ($ProgressId) {
            $last = $null
            Get-Event -SourceIdentifier $ProgressId -ErrorAction SilentlyContinue | ForEach-Object {
                $last = $_.SourceEventArgs
                Remove-Event -EventIdentifier $_.EventIdentifier -ErrorAction SilentlyContinue
            }
            if ($last) {
                Write-Verbose ('Download: {0}% ({1}/{2} bytes)' -f $last.ProgressPercentage, $last.BytesCompleted, $last.BytesTotal)
                if ($ShowProgress) {
                    if ($last.ProgressPercentage -ge 100) {
                        Write-CoProgress -Activity $Activity -Status 'Finalizing application ...' -Percent 100
                    }
                    else {
                        $detail = if ($last.BytesTotal -gt 0) {
                            '{0:N1} of {1:N1} MB' -f ($last.BytesCompleted / 1MB), ($last.BytesTotal / 1MB)
                        } else { 'in progress ...' }
                        Write-CoProgress -Activity $Activity -Status "Download: $detail" -Percent $last.ProgressPercentage
                    }
                }
            }
        }
        if ($ev) {
            $ea = $ev.SourceEventArgs
            Remove-Event -EventIdentifier $ev.EventIdentifier -ErrorAction SilentlyContinue
            return $ea
        }
    }
    $null
}
