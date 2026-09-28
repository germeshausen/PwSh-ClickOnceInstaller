function Invoke-CoInWindowsPowerShell {
    # Runs a module function in Windows PowerShell 5.1 (needed for PS 7, which lacks System.Deployment).
    # Protocol: parameters go in as Base64 JSON; progress comes back as '##CO-PROGRESS {json}' lines;
    # the last line starting with '{' is the JSON-serialized result object.
    param(
        [string]$FunctionName,
        [System.Collections.IDictionary]$Parameters
    )
    $exe = Join-Path $env:windir 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $h = @{}
    foreach ($k in $Parameters.Keys) {
        $v = $Parameters[$k]
        if ($v -is [switch]) { $v = $v.IsPresent }
        $h[$k] = $v
    }
    $b64  = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($h | ConvertTo-Json -Compress)))
    $mod  = $script:ManifestPath.Replace("'", "''")
    $code = @"
`$ProgressPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
`$env:SILENTCLICKONCE_BRIDGE = '1'
Import-Module -Force -Name '$mod'
`$o = ConvertFrom-Json ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$b64')))
`$p = @{}
foreach (`$pr in `$o.PSObject.Properties) { `$p[`$pr.Name] = `$pr.Value }
& '$FunctionName' @p | ConvertTo-Json -Compress
"@
    $enc     = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code))
    $lines   = [System.Collections.Generic.List[string]]::new()
    $lastAct = $null
    $oldEnc  = $null
    try {
        try { $oldEnc = [Console]::OutputEncoding; [Console]::OutputEncoding = [Text.Encoding]::UTF8 }
        catch { Write-Verbose "Could not set console output encoding: $($_.Exception.Message)" }
        & $exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $enc | ForEach-Object {
            $line = [string]$_
            if ($line.StartsWith('##CO-PROGRESS ')) {
                $pg = $line.Substring(14) | ConvertFrom-Json
                $lastAct = $pg.Activity
                Write-CoProgress -Activity $pg.Activity -Status $pg.Status -Percent $pg.Percent -Completed:([bool]$pg.Completed)
            }
            else { $lines.Add($line) }
        }
    }
    finally {
        if ($oldEnc) {
            try { [Console]::OutputEncoding = $oldEnc }
            catch { Write-Verbose "Could not restore console output encoding: $($_.Exception.Message)" }
        }
        if ($lastAct) { Write-Progress -Activity $lastAct -Completed }
    }
    $json = $lines | Where-Object { $_ -like '{*' } | Select-Object -Last 1
    if (-not $json) {
        return New-CoResult -Operation $FunctionName -ExitCode 1 -Status 'BridgeError' `
            -Message 'No response received from Windows PowerShell 5.1.'
    }
    $r = $json | ConvertFrom-Json
    $global:LASTEXITCODE = [int]$r.ExitCode
    $r
}
