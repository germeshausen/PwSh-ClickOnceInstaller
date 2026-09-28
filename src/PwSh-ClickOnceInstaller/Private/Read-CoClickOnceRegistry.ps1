function Read-CoClickOnceRegistry {
    # Reads the ClickOnce component store (HKCU\...\Deployment\SideBySide\2.0): Components and Marks.
    # Port of ClickOnceRegistry from Wunder.ClickOnceUninstaller (MIT, see THIRD-PARTY-NOTICES.md).
    $base       = 'Software\Classes\Software\Microsoft\Windows\CurrentVersion\Deployment\SideBySide\2.0'
    $components = [System.Collections.Generic.List[object]]::new()
    $marks      = [System.Collections.Generic.List[object]]::new()

    $root = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("$base\Components")
    if ($root) {
        try {
            foreach ($name in $root.GetSubKeyNames()) {
                $key = $root.OpenSubKey($name)
                if (-not $key) { continue }
                try {
                    $components.Add([pscustomobject]@{
                            Key          = $name
                            Dependencies = [string[]]@($key.GetSubKeyNames() | Where-Object { $_ -ne 'Files' })
                        })
                }
                finally { $key.Dispose() }
            }
        }
        finally { $root.Dispose() }
    }

    $root = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("$base\Marks")
    if ($root) {
        try {
            foreach ($name in $root.GetSubKeyNames()) {
                $key = $root.OpenSubKey($name)
                if (-not $key) { continue }
                try {
                    $implications = [System.Collections.Generic.List[object]]::new()
                    foreach ($valueName in $key.GetValueNames()) {
                        # value name = 'implication' + 1 separator character + component key
                        if ($valueName.Length -gt 12 -and $valueName.StartsWith('implication', [StringComparison]::Ordinal)) {
                            $bytes = $key.GetValue($valueName)
                            if ($bytes -is [byte[]]) {
                                $implications.Add([pscustomobject]@{
                                        Key   = $valueName
                                        Name  = $valueName.Substring(12)
                                        Value = [Text.Encoding]::ASCII.GetString($bytes)
                                    })
                            }
                        }
                    }
                    $marks.Add([pscustomobject]@{ Key = $name; Implications = $implications.ToArray() })
                }
                finally { $key.Dispose() }
            }
        }
        finally { $root.Dispose() }
    }

    [pscustomobject]@{ Components = $components.ToArray(); Marks = $marks.ToArray() }
}
