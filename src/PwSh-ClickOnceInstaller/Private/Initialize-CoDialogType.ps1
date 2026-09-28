function Initialize-CoDialogType {
    # Compiles the Win32 helper (Private\CoDialog.cs) once per session.
    if ('CoDialog' -as [type]) { return }
    $source = Join-Path -Path (Join-Path $script:ModuleRoot 'Private') -ChildPath 'CoDialog.cs'
    Add-Type -TypeDefinition (Get-Content -LiteralPath $source -Raw)
}
