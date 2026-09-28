function Invoke-CoPlanAction {
    # Executes one action from Get-CoUninstallPlan. Throws on failure; missing items are not an error.
    param([Parameter(Mandatory)]$Action)

    switch ($Action.Type) {
        'Folder' {
            if ($Action.Recursive) { Remove-Item -LiteralPath $Action.Path -Recurse -Force -ErrorAction Stop }
            else { [System.IO.Directory]::Delete($Action.Path, $false) }   # only if empty
        }
        'File' {
            Remove-Item -LiteralPath $Action.Path -Force -ErrorAction Stop
        }
        'RegistryKey' {
            $parent = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($Action.Parent, $true)
            if ($parent) {
                try { $parent.DeleteSubKeyTree($Action.Name, $false) }
                finally { $parent.Dispose() }
            }
        }
        'RegistryValue' {
            $parent = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($Action.Parent, $true)
            if ($parent) {
                try { $parent.DeleteValue($Action.Name, $false) }
                finally { $parent.Dispose() }
            }
        }
    }
}
