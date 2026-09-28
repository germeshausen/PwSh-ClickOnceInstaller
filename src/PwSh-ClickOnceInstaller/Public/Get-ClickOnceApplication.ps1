function Get-ClickOnceApplication {
    <#
    .SYNOPSIS
        Lists the ClickOnce applications installed for the current user.

    .DESCRIPTION
        Reads the uninstall entries under HKCU and returns all applications that were installed via
        ClickOnce (dfshim.dll / ShArpMaintain). The output is also the source for tab completion of
        Uninstall-ClickOnceApplication -Name.

    .PARAMETER Name
        Filter on the display name (wildcards allowed). Default: * (all).

    .EXAMPLE
        Get-ClickOnceApplication

    .EXAMPLE
        Get-ClickOnceApplication -Name 'My*'

    .OUTPUTS
        PSCustomObject with Name, Publisher, Version, PublicKeyToken, UninstallArguments, RegistryKey, Key and
        the shortcut names (ShortcutFolderName, ShortcutSuiteName, ShortcutFileName, SupportShortcutFileName).

    .LINK
        Uninstall-ClickOnceApplication
    #>
    [CmdletBinding()]
    param([string]$Name = '*')

    $root = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall'
    Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue | ForEach-Object {
        $p = Get-ItemProperty -LiteralPath $_.PSPath
        if ($p.UninstallString -match 'dfshim\.dll,\s*ShArpMaintain\s+(?<arg>.+)$' -and $p.DisplayName -like $Name) {
            $arguments = $Matches['arg']
            $token     = $null
            if ($arguments -match 'PublicKeyToken=(?<token>[0-9a-fA-F]{16})') { $token = $Matches['token'] }

            [pscustomobject]@{
                Name                    = $p.DisplayName
                Publisher               = $p.Publisher
                Version                 = $p.DisplayVersion
                PublicKeyToken          = $token
                UninstallArguments      = $arguments
                RegistryKey             = $_.PSPath
                Key                     = ($_.PSPath -split '\\')[-1]
                ShortcutFolderName      = $p.ShortcutFolderName
                ShortcutSuiteName       = $p.ShortcutSuiteName
                ShortcutFileName        = $p.ShortcutFileName
                SupportShortcutFileName = $p.SupportShortcutFileName
            }
        }
    }
}
