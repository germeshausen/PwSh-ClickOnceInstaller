#Requires -Version 5.1
# PwSh-ClickOnceInstaller - silent install/uninstall of ClickOnce applications
# Author: Sven Germeshausen (https://github.com/germeshausen)
# Inspired by the function of SilentClickOnce.exe (https://github.com/PaaaulZ/SilentClickOnce)
#
# This file only loads the function files. Public functions live in Public\, helpers in Private\.
# The manifest (PwSh-ClickOnceInstaller.psd1) controls what is exported.

$script:ModuleRoot   = $PSScriptRoot
$script:ManifestPath = Join-Path -Path $PSScriptRoot -ChildPath 'PwSh-ClickOnceInstaller.psd1'

$privateFiles = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
$publicFiles  = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public')  -Filter '*.ps1' -File -ErrorAction SilentlyContinue)

foreach ($file in @($privateFiles + $publicFiles)) {
    try { . $file.FullName }
    catch { throw "Failed to load '$($file.Name)': $($_.Exception.Message)" }
}

Export-ModuleMember -Function $publicFiles.BaseName
