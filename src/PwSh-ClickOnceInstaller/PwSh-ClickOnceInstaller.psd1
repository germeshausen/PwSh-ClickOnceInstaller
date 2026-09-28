@{
    RootModule            = 'PwSh-ClickOnceInstaller.psm1'
    ModuleVersion         = '0.3.0.0'
    GUID                  = '830ce8e6-ad73-4986-bf5d-2fb99992e326'
    Author                = 'Sven Germeshausen'
    Copyright             = '(c) 2026 Sven Germeshausen.'
    Description           = 'Silent install and uninstall of ClickOnce applications without user interaction, with status and exit codes. Inspired by SilentClickOnce.exe (PaaaulZ/SilentClickOnce).'
    PowerShellVersion     = '5.1'
    CompatiblePSEditions  = @('Desktop', 'Core')

    FunctionsToExport     = @(
        'Get-ClickOnceApplication'
        'Install-ClickOnceApplication'
        'Uninstall-ClickOnceApplication'
    )
    CmdletsToExport       = @()
    VariablesToExport     = @()
    AliasesToExport       = @()

    PrivateData           = @{
        PSData = @{
            Tags         = @('ClickOnce', 'Installer', 'Silent', 'Deployment', 'Windows', 'Automation')
            LicenseUri   = 'https://github.com/germeshausen/PwSh-ClickOnceInstaller/blob/master/LICENSE'
            ProjectUri   = 'https://github.com/germeshausen/PwSh-ClickOnceInstaller'
            ReleaseNotes = '0.3.0.0 - First Public Release - Beta. See CHANGELOG.md.'
        }
    }
}
