# Pester 5 tests. Run with: ./build.ps1 -Task Test
BeforeDiscovery {
    $onWindows       = ($PSVersionTable.PSEdition -eq 'Desktop') -or $IsWindows
    $publicFunctions = @('Get-ClickOnceApplication', 'Install-ClickOnceApplication', 'Uninstall-ClickOnceApplication')
}

BeforeAll {
    $script:ManifestPath = Join-Path $PSScriptRoot '..\src\PwSh-ClickOnceInstaller\PwSh-ClickOnceInstaller.psd1'
    $script:Expected     = @('Get-ClickOnceApplication', 'Install-ClickOnceApplication', 'Uninstall-ClickOnceApplication')
    Import-Module $script:ManifestPath -Force
}

AfterAll {
    Remove-Module PwSh-ClickOnceInstaller -ErrorAction SilentlyContinue
}

Describe 'Module manifest' {
    It 'is valid' {
        { Test-ModuleManifest -Path $script:ManifestPath -ErrorAction Stop } | Should -Not -Throw
    }
    It 'has the expected version and author' {
        $m = Test-ModuleManifest -Path $script:ManifestPath
        $m.Version | Should -Be ([version]'0.3.0.0')
        $m.Author  | Should -Be 'Sven Germeshausen'
    }
    It 'exports exactly the public functions' {
        $exported = (Get-Module PwSh-ClickOnceInstaller).ExportedFunctions.Keys
        Compare-Object -ReferenceObject $script:Expected -DifferenceObject @($exported) | Should -BeNullOrEmpty
    }
}

Describe 'Comment-based help' {
    It '<_> has synopsis, description and example' -ForEach $publicFunctions {
        $h = Get-Help $_ -Full
        $h.Synopsis    | Should -Not -BeNullOrEmpty
        $h.Synopsis    | Should -Not -BeLike "$_*"   # an auto-generated synopsis starts with the syntax line
        $h.Description | Should -Not -BeNullOrEmpty
        $h.Examples    | Should -Not -BeNullOrEmpty
    }
}

Describe 'Parameters' {
    It 'Install-ClickOnceApplication has Uri, TimeoutSec, Launch and Silent' {
        $c = Get-Command Install-ClickOnceApplication
        $c | Should -HaveParameter Uri -Mandatory
        $c | Should -HaveParameter TimeoutSec -Type int
        $c | Should -HaveParameter Launch -Type switch
        $c | Should -HaveParameter Silent -Type switch
    }
    It 'Uninstall-ClickOnceApplication has Name (with argument completer), Method, Force, Silent and -WhatIf' {
        $c = Get-Command Uninstall-ClickOnceApplication
        $c | Should -HaveParameter Name -Mandatory
        $c | Should -HaveParameter Method
        $c | Should -HaveParameter TimeoutSec -Type int
        $c | Should -HaveParameter Force -Type switch
        $c | Should -HaveParameter Silent -Type switch
        $c | Should -HaveParameter WhatIf
        $attributeNames = $c.Parameters['Name'].Attributes | ForEach-Object { $_.GetType().Name }
        $attributeNames | Should -Contain 'ArgumentCompleterAttribute'
    }
}

Describe 'Get-ClickOnceApplication' {
    BeforeAll {
        Mock -ModuleName PwSh-ClickOnceInstaller Get-ChildItem {
            @([pscustomobject]@{ PSPath = 'HKCU:\fake\1' }, [pscustomobject]@{ PSPath = 'HKCU:\fake\2' })
        }
        Mock -ModuleName PwSh-ClickOnceInstaller Get-ItemProperty {
            if ($LiteralPath -like '*1') {
                [pscustomobject]@{
                    DisplayName        = 'MyApp'
                    Publisher          = 'Contoso'
                    DisplayVersion     = '1.2.3.4'
                    ShortcutFolderName = 'Contoso'
                    ShortcutFileName   = 'MyApp'
                    UninstallString    = 'rundll32.exe dfshim.dll,ShArpMaintain MyApp.application, Culture=neutral, PublicKeyToken=0123456789abcdef, processorArchitecture=msil'
                }
            }
            else {
                [pscustomobject]@{ DisplayName = 'Other'; UninstallString = '"C:\Tools\uninstall.exe" /S' }
            }
        }
    }
    It 'returns only ClickOnce entries' {
        $r = @(Get-ClickOnceApplication)
        $r.Count                 | Should -Be 1
        $r[0].Name               | Should -Be 'MyApp'
        $r[0].Publisher          | Should -Be 'Contoso'
        $r[0].UninstallArguments | Should -Match '^MyApp\.application, Culture=neutral'
    }
    It 'extracts the public key token, the registry key name and the shortcut names' {
        $r = @(Get-ClickOnceApplication)
        $r[0].PublicKeyToken     | Should -Be '0123456789abcdef'
        $r[0].Key                | Should -Be '1'
        $r[0].ShortcutFolderName | Should -Be 'Contoso'
        $r[0].ShortcutFileName   | Should -Be 'MyApp'
    }
    It 'filters by name' {
        @(Get-ClickOnceApplication -Name 'Nope*').Count | Should -Be 0
    }
}

Describe 'Get-CoComponentToRemove' {
    BeforeAll {
        $script:comps = @(
            [pscustomobject]@{ Key = 'myapp_aaaaaaaaaaaaaaaa_1'; Dependencies = [string[]]@('shared_bbbbbbbbbbbbbbbb_1', 'solo_cccccccccccccccc_1', 'nomark_ffffffffffffffff_1', 'private_gggg') }
            [pscustomobject]@{ Key = 'shared_bbbbbbbbbbbbbbbb_1'; Dependencies = [string[]]@() }
            [pscustomobject]@{ Key = 'solo_cccccccccccccccc_1'; Dependencies = [string[]]@() }
            [pscustomobject]@{ Key = 'nomark_ffffffffffffffff_1'; Dependencies = [string[]]@() }
            [pscustomobject]@{ Key = 'other_eeeeeeeeeeeeeeee_1'; Dependencies = [string[]]@() }
        )
        $script:marks = @(
            [pscustomobject]@{ Key = 'shared_bbbbbbbbbbbbbbbb_1'; Implications = @(
                    [pscustomobject]@{ Key = 'implication_x'; Name = 'myapp_aaaaaaaaaaaaaaaa_1' }
                    [pscustomobject]@{ Key = 'implication_y'; Name = 'other_eeeeeeeeeeeeeeee_1' }) }
            [pscustomobject]@{ Key = 'solo_cccccccccccccccc_1'; Implications = @(
                    [pscustomobject]@{ Key = 'implication_x'; Name = 'myapp_aaaaaaaaaaaaaaaa_1' }) }
        )
    }
    It 'removes own components and unshared dependencies, keeps shared and non-public ones' {
        $r = @(InModuleScope PwSh-ClickOnceInstaller -Parameters @{ c = $script:comps; m = $script:marks } {
                param($c, $m)
                Get-CoComponentToRemove -Token 'aaaaaaaaaaaaaaaa' -Components $c -Marks $m
            })
        $r | Should -Contain 'myapp_aaaaaaaaaaaaaaaa_1'
        $r | Should -Contain 'solo_cccccccccccccccc_1'      # only implied by the application itself
        $r | Should -Contain 'nomark_ffffffffffffffff_1'    # no mark, nobody else depends on it
        $r | Should -Not -Contain 'shared_bbbbbbbbbbbbbbbb_1' # still implied by another application
        $r | Should -Not -Contain 'other_eeeeeeeeeeeeeeee_1'
        $r | Should -Not -Contain 'private_gggg'             # not a public component
    }
    It 'returns nothing for an unknown token' {
        $r = @(InModuleScope PwSh-ClickOnceInstaller -Parameters @{ c = $script:comps; m = $script:marks } {
                param($c, $m)
                Get-CoComponentToRemove -Token '0000000000000000' -Components $c -Marks $m
            })
        $r.Count | Should -Be 0
    }
}

Describe 'Install-ClickOnceApplication input validation' -Skip:(-not $onWindows) {
    It 'returns exit code 2 for "<uri>"' -ForEach @(
        @{ uri = 'not a uri' }
        @{ uri = 'ftp://example.com/app.application' }
        @{ uri = 'relative/app.application' }
    ) {
        $r = Install-ClickOnceApplication -Uri $uri
        $r.ExitCode   | Should -Be 2
        $r.Success    | Should -BeFalse
        $LASTEXITCODE | Should -Be 2
    }
}

Describe 'Uninstall-ClickOnceApplication' -Skip:(-not $onWindows) {
    Context 'lookup' {
        It 'returns exit code 7 when no application matches' {
            Mock -ModuleName PwSh-ClickOnceInstaller Get-ClickOnceApplication { @() }
            (Uninstall-ClickOnceApplication -Name 'Nope').ExitCode | Should -Be 7
        }
        It 'returns exit code 10 when the name is not unique' {
            Mock -ModuleName PwSh-ClickOnceInstaller Get-ClickOnceApplication {
                @([pscustomobject]@{ Name = 'App One' }, [pscustomobject]@{ Name = 'App Two' })
            }
            (Uninstall-ClickOnceApplication -Name 'App*').ExitCode | Should -Be 10
        }
    }

    Context 'method Direct' {
        BeforeAll {
            Mock -ModuleName PwSh-ClickOnceInstaller Get-ClickOnceApplication {
                $pattern = if ($Name) { $Name } else { '*' }
                @(
                    [pscustomobject]@{ Name = 'App One'; PublicKeyToken = 'aaaaaaaaaaaaaaaa'; RegistryKey = 'HKCU:\Software\SilentClickOnceTests\One' }
                    [pscustomobject]@{ Name = 'App Two'; PublicKeyToken = 'aaaaaaaaaaaaaaaa'; RegistryKey = 'HKCU:\Software\SilentClickOnceTests\Two' }
                    [pscustomobject]@{ Name = 'Solo App'; PublicKeyToken = 'bbbbbbbbbbbbbbbb'; RegistryKey = 'HKCU:\Software\SilentClickOnceTests\Solo' }
                ) | Where-Object { $_.Name -like $pattern }
            }
            Mock -ModuleName PwSh-ClickOnceInstaller Read-CoClickOnceRegistry { [pscustomobject]@{ Components = @(); Marks = @() } }
            Mock -ModuleName PwSh-ClickOnceInstaller Get-CoUninstallPlan {
                [pscustomobject]@{
                    Components = @('x')
                    Actions    = @(
                        [pscustomobject]@{ Type = 'File'; Target = 'C:\fake\a.txt'; Description = 'Delete file' }
                        [pscustomobject]@{ Type = 'RegistryKey'; Target = 'HKCU:\fake\b'; Description = 'Delete registry key' }
                    )
                }
            }
            Mock -ModuleName PwSh-ClickOnceInstaller Invoke-CoPlanAction { }
        }
        It 'stops with exit code 11 when another application uses the same publisher key' {
            $r = Uninstall-ClickOnceApplication -Name 'App One' -Silent
            $r.ExitCode | Should -Be 11
            $r.Status   | Should -Be 'SharedPublisherKey'
        }
        It 'executes every planned action for an application with its own publisher key' {
            $r = Uninstall-ClickOnceApplication -Name 'Solo App' -Silent
            $r.ExitCode | Should -Be 0
            $r.Status   | Should -Be 'Uninstalled'
            $r.Method   | Should -Be 'Direct'
            Should -Invoke Invoke-CoPlanAction -ModuleName PwSh-ClickOnceInstaller -Times 2 -Exactly
        }
        It 'continues despite a shared publisher key with -Force' {
            (Uninstall-ClickOnceApplication -Name 'App One' -Force -Silent).ExitCode | Should -Be 0
        }
        It 'changes nothing with -WhatIf' {
            $r = Uninstall-ClickOnceApplication -Name 'Solo App' -Silent -WhatIf
            $r.ExitCode | Should -Be 0
            $r.Status   | Should -Be 'WhatIf'
            $r.PlannedActions | Should -Be 2
            Should -Invoke Invoke-CoPlanAction -ModuleName PwSh-ClickOnceInstaller -Times 0 -Exactly
        }
    }
}
