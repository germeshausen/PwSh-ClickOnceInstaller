function New-CoResult {
    # Builds the result object returned by all public functions and sets $LASTEXITCODE.
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param(
        [string]$Operation,
        [int]$ExitCode,
        [string]$Status,
        [string]$Message,
        [hashtable]$Data
    )
    $o = [ordered]@{
        Operation = $Operation
        Success   = ($ExitCode -eq 0)
        ExitCode  = $ExitCode
        Status    = $Status
        Message   = $Message
    }
    if ($Data) { foreach ($k in $Data.Keys) { $o[$k] = $Data[$k] } }
    $global:LASTEXITCODE = $ExitCode
    [pscustomobject]$o
}
