function Test-CoWindows {
    # $IsWindows does not exist in Windows PowerShell 5.1 (which only runs on Windows).
    ($PSVersionTable.PSEdition -eq 'Desktop') -or $IsWindows
}
