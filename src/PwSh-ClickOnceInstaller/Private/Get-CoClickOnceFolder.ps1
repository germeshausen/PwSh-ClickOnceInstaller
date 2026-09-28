function Get-CoClickOnceFolder {
    # Returns the ClickOnce application cache folders: %LOCALAPPDATA%\Apps\2.0\<12 chars>\<12 chars>
    # (Wunder.ClickOnceUninstaller only used the first match; all matches are returned here.)
    $apps20 = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Apps\2.0'
    if (-not (Test-Path -LiteralPath $apps20 -PathType Container)) { return }

    foreach ($first in Get-ChildItem -LiteralPath $apps20 -Directory -Force -ErrorAction SilentlyContinue) {
        if ($first.Name.Length -ne 12) { continue }
        foreach ($second in Get-ChildItem -LiteralPath $first.FullName -Directory -Force -ErrorAction SilentlyContinue) {
            if ($second.Name.Length -eq 12) { $second.FullName }
        }
    }
}
