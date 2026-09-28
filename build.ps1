<#
.SYNOPSIS
    Local build/QA entry point (also used by CI).
.EXAMPLE
    ./build.ps1 -Task Lint    # PSScriptAnalyzer
    ./build.ps1 -Task Test    # Pester 5
    ./build.ps1               # both
#>
[CmdletBinding()]
param(
    [ValidateSet('Lint', 'Test', 'All')]
    [string]$Task = 'All'
)

$root = $PSScriptRoot

function Invoke-Lint {
    Import-Module PSScriptAnalyzer -ErrorAction Stop
    $findings = @(Invoke-ScriptAnalyzer -Path (Join-Path $root 'src') -Recurse `
            -Settings (Join-Path $root 'PSScriptAnalyzerSettings.psd1'))
    if ($findings.Count) {
        $findings | Format-Table RuleName, Severity, ScriptName, Line, Message -AutoSize -Wrap | Out-String | Write-Host
    }
    if ($findings | Where-Object Severity -eq 'Error') { throw 'PSScriptAnalyzer reported errors.' }
    Write-Host "PSScriptAnalyzer: $($findings.Count) finding(s), no errors."
}

function Invoke-Test {
    Import-Module Pester -MinimumVersion 5.5.0 -ErrorAction Stop
    $cfg = New-PesterConfiguration
    $cfg.Run.Path             = Join-Path $root 'tests'
    $cfg.Run.PassThru         = $true
    $cfg.Output.Verbosity     = 'Detailed'
    $result = Invoke-Pester -Configuration $cfg
    if ($result.FailedCount -gt 0) { throw "$($result.FailedCount) test(s) failed." }
}

if ($Task -in 'Lint', 'All') { Invoke-Lint }
if ($Task -in 'Test', 'All') { Invoke-Test }
