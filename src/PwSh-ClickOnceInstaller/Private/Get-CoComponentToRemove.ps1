function Get-CoComponentToRemove {
    # Determines which ClickOnce components (SideBySide\2.0\Components) belong to an application.
    # Port of Uninstaller.FindComponentsToRemove from Wunder.ClickOnceUninstaller (MIT, see THIRD-PARTY-NOTICES.md).
    #
    # - Own components: every component whose key contains the application's PublicKeyToken.
    # - Dependencies of own components are removed as well, unless they are not a public component or
    #   another (foreign) component still "implies" them via the Marks registry.
    param(
        [Parameter(Mandatory)][string]$Token,
        [object[]]$Components = @(),
        [object[]]$Marks = @()
    )

    $own      = @($Components | Where-Object { $_.Key.IndexOf($Token, [StringComparison]::OrdinalIgnoreCase) -ge 0 })
    $ownKeys  = @($own | ForEach-Object { $_.Key })
    $allKeys  = @($Components | ForEach-Object { $_.Key })
    $toRemove = [System.Collections.Generic.List[string]]::new()

    foreach ($component in $own) {
        if ($toRemove -notcontains $component.Key) { $toRemove.Add($component.Key) }

        foreach ($dependency in $component.Dependencies) {
            if ($toRemove -contains $dependency) { continue }    # already in the list
            if ($allKeys -notcontains $dependency) { continue }  # not a public component

            $mark = $Marks | Where-Object { $_.Key -eq $dependency } | Select-Object -First 1
            if ($mark -and @($mark.Implications | Where-Object { $ownKeys -notcontains $_.Name }).Count -gt 0) {
                continue                                         # other applications still depend on it
            }
            $toRemove.Add($dependency)
        }
    }

    $toRemove.ToArray()
}
