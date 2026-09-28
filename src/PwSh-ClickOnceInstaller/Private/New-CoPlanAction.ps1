function New-CoPlanAction {
    # One planned uninstall action (delete folder/file/registry key/registry value).
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param(
        [Parameter(Mandatory)][ValidateSet('Folder', 'File', 'RegistryKey', 'RegistryValue')][string]$Type,
        [string]$Path,       # Folder/File
        [string]$Parent,     # RegistryKey/RegistryValue: path below HKCU
        [string]$Name,       # RegistryKey/RegistryValue: key or value name
        [switch]$Recursive
    )
    switch ($Type) {
        'Folder'        { $target = $Path;                        $description = 'Delete folder' }
        'File'          { $target = $Path;                        $description = 'Delete file' }
        'RegistryKey'   { $target = "HKCU:\$Parent\$Name";        $description = 'Delete registry key' }
        'RegistryValue' { $target = "HKCU:\$Parent [$Name]";      $description = 'Delete registry value' }
    }
    [pscustomobject]@{
        Type        = $Type
        Target      = $target
        Description = $description
        Path        = $Path
        Parent      = $Parent
        Name        = $Name
        Recursive   = $Recursive.IsPresent
    }
}
