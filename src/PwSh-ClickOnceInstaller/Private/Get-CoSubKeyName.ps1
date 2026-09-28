function Get-CoSubKeyName {
    # Returns the sub key names below an HKCU path (empty if the key does not exist).
    # Uses the .NET registry API on purpose: ClickOnce key names can contain characters that
    # confuse the PowerShell registry provider (wildcards).
    param([Parameter(Mandatory)][string]$Path)

    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($Path)
    if (-not $key) { return }
    try { $key.GetSubKeyNames() }
    finally { $key.Dispose() }
}
