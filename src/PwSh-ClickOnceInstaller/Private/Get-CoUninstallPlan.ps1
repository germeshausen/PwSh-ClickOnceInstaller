function Get-CoUninstallPlan {
    # Builds the list of actions that imitate the ClickOnce uninstaller for one application:
    #   1. delete component folders and manifests in the ClickOnce cache (Apps\2.0)
    #   2. delete start menu / desktop shortcuts (and now empty shortcut folders)
    #   3. delete registry keys/values of the component store
    #   4. delete the "Apps & features" uninstall entry
    # Port of Uninstaller, RemoveFiles, RemoveStartMenuEntry, RemoveRegistryKeys and RemoveUninstallEntry from
    # Wunder.ClickOnceUninstaller (MIT, see THIRD-PARTY-NOTICES.md).
    param(
        [Parameter(Mandatory)]$App,        # object from Get-ClickOnceApplication
        [Parameter(Mandatory)]$Registry    # object from Read-CoClickOnceRegistry
    )

    $token      = $App.PublicKeyToken
    $components = @(Get-CoComponentToRemove -Token $token -Components $Registry.Components -Marks $Registry.Marks)
    $actions    = [System.Collections.Generic.List[object]]::new()
    $base       = 'Software\Classes\Software\Microsoft\Windows\CurrentVersion\Deployment\SideBySide\2.0'

    # 1) ClickOnce cache: component folders and manifests\<component>.*
    foreach ($root in Get-CoClickOnceFolder) {
        foreach ($dir in Get-ChildItem -LiteralPath $root -Directory -Force -ErrorAction SilentlyContinue) {
            if ($components -contains $dir.Name) {
                $actions.Add((New-CoPlanAction -Type Folder -Path $dir.FullName -Recursive))
            }
        }
        $manifests = Join-Path $root 'manifests'
        if (Test-Path -LiteralPath $manifests -PathType Container) {
            foreach ($file in Get-ChildItem -LiteralPath $manifests -File -Force -ErrorAction SilentlyContinue) {
                if ($components -contains [IO.Path]::GetFileNameWithoutExtension($file.Name)) {
                    $actions.Add((New-CoPlanAction -Type File -Path $file.FullName))
                }
            }
        }
    }

    # 2) Start menu and desktop shortcuts
    $programs = [Environment]::GetFolderPath('Programs')
    $desktop  = [Environment]::GetFolderPath('DesktopDirectory')
    $folder   = [IO.Path]::Combine($programs, [string]$App.ShortcutFolderName)
    $suite    = [IO.Path]::Combine($folder, [string]$App.ShortcutSuiteName)

    $candidates = [System.Collections.Generic.List[string]]::new()
    if ($App.ShortcutFileName) {
        $candidates.Add([IO.Path]::Combine($suite, "$($App.ShortcutFileName).appref-ms"))
        $candidates.Add([IO.Path]::Combine($desktop, "$($App.ShortcutFileName).appref-ms"))
    }
    if ($App.SupportShortcutFileName) {
        $candidates.Add([IO.Path]::Combine($suite, "$($App.SupportShortcutFileName).url"))
    }
    $shortcuts = @($candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
    foreach ($shortcut in $shortcuts) {
        $actions.Add((New-CoPlanAction -Type File -Path $shortcut))
    }

    # Remove the shortcut folder(s) only if nothing else is left in them (never the Programs folder itself).
    if ($suite -ne $programs -and (Test-Path -LiteralPath $suite -PathType Container)) {
        $foreign = @(Get-ChildItem -LiteralPath $suite -File -Force -ErrorAction SilentlyContinue |
                Where-Object { $shortcuts -notcontains $_.FullName })
        if ($foreign.Count -eq 0) {
            $actions.Add((New-CoPlanAction -Type Folder -Path $suite))
            if ($folder -ne $suite -and $folder -ne $programs) {
                $subFolders = @(Get-ChildItem -LiteralPath $folder -Directory -Force -ErrorAction SilentlyContinue)
                $files      = @(Get-ChildItem -LiteralPath $folder -File -Force -ErrorAction SilentlyContinue)
                if ($subFolders.Count -eq 1 -and $files.Count -eq 0) {
                    $actions.Add((New-CoPlanAction -Type Folder -Path $folder))
                }
            }
        }
    }

    # 3) Component store in the registry
    foreach ($component in $Registry.Components) {
        if ($components -contains $component.Key) {
            $actions.Add((New-CoPlanAction -Type RegistryKey -Parent "$base\Components" -Name $component.Key))
        }
    }
    foreach ($mark in $Registry.Marks) {
        if ($components -contains $mark.Key) {
            $actions.Add((New-CoPlanAction -Type RegistryKey -Parent "$base\Marks" -Name $mark.Key))
        }
        else {
            foreach ($implication in $mark.Implications) {
                if ($components -contains $implication.Name) {
                    $actions.Add((New-CoPlanAction -Type RegistryValue -Parent "$base\Marks\$($mark.Key)" -Name $implication.Key))
                }
            }
        }
    }

    # keys named after the application's public key token
    foreach ($metaName in @(Get-CoSubKeyName -Path "$base\PackageMetadata")) {
        $metaPath = "$base\PackageMetadata\$metaName"
        foreach ($name in @(Get-CoSubKeyName -Path $metaPath)) {
            if ($name.IndexOf($token, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                $actions.Add((New-CoPlanAction -Type RegistryKey -Parent $metaPath -Name $name))
            }
        }
    }
    foreach ($path in "$base\StateManager\Applications", "$base\StateManager\Families", "$base\Visibility") {
        foreach ($name in @(Get-CoSubKeyName -Path $path)) {
            if ($name.IndexOf($token, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                $actions.Add((New-CoPlanAction -Type RegistryKey -Parent $path -Name $name))
            }
        }
    }

    # 4) "Apps & features" entry (last, so an aborted run can be repeated)
    $actions.Add((New-CoPlanAction -Type RegistryKey -Parent 'Software\Microsoft\Windows\CurrentVersion\Uninstall' -Name $App.Key))

    [pscustomobject]@{ Components = $components; Actions = $actions.ToArray() }
}
