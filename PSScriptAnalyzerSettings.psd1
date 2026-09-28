@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        # $global:LASTEXITCODE is set on purpose so callers can rely on the exit code after a call.
        'PSAvoidGlobalVars'
    )
}
