function Install-ClickOnceApplication {
    <#
    .SYNOPSIS
        Installs a ClickOnce application without any user interaction.

    .DESCRIPTION
        Downloads the deployment manifest (.application) from a URL or UNC path, verifies the requirements,
        grants application trust without prompting and installs the application for the current user
        (InPlaceHostingManager). Progress is shown via Write-Progress; use -Silent to suppress it.
        Under PowerShell 7 the installation is automatically executed in Windows PowerShell 5.1.

    .PARAMETER Uri
        URL (http/https) or UNC/file path to the .application file.

    .PARAMETER TimeoutSec
        Maximum total time in seconds for the manifest download and the installation. Default: 300.

    .PARAMETER Launch
        Starts the application after a successful installation.

    .PARAMETER Silent
        Suppresses the progress display (Write-Progress).

    .EXAMPLE
        Install-ClickOnceApplication '\\server\apps\MyApp\MyApp.application'

    .EXAMPLE
        $r = Install-ClickOnceApplication 'https://example.com/MyApp.application' -Silent
        exit $r.ExitCode

    .OUTPUTS
        PSCustomObject with Operation, Success, ExitCode, Status, Message and, if available, ProductName,
        Version, ShortcutAppId and LogFilePath. Also sets $LASTEXITCODE.

    .LINK
        Uninstall-ClickOnceApplication
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Uri,
        [ValidateRange(10, 3600)][int]$TimeoutSec = 300,
        [switch]$Launch,
        [switch]$Silent
    )

    if (-not (Test-CoWindows)) {
        return New-CoResult 'Install' 9 'Unsupported' 'ClickOnce is only supported on Windows.'
    }

    $u = $null
    if (-not [uri]::TryCreate($Uri, [System.UriKind]::Absolute, [ref]$u) -or $u.Scheme -notin 'http', 'https', 'file') {
        return New-CoResult 'Install' 2 'InvalidUri' "Invalid URI: $Uri"
    }

    if ($PSVersionTable.PSEdition -eq 'Core') {
        return Invoke-CoInWindowsPowerShell -FunctionName $MyInvocation.MyCommand.Name -Parameters $PSBoundParameters
    }

    try { Add-Type -AssemblyName System.Deployment -ErrorAction Stop }
    catch { return New-CoResult 'Install' 9 'Unsupported' "Unable to load System.Deployment: $($_.Exception.Message)" }

    $activity = 'ClickOnce installation'
    $show     = -not $Silent
    $id       = [guid]::NewGuid().ToString('N')
    $deadline = [datetime]::UtcNow.AddSeconds($TimeoutSec)
    $iphm     = $null
    try {
        try { $iphm = [System.Deployment.Application.InPlaceHostingManager]::new($u, [bool]$Launch) }
        catch { return New-CoResult 'Install' 1 'Error' "Unable to create InPlaceHostingManager: $($_.Exception.Message)" }

        Register-ObjectEvent -InputObject $iphm -EventName GetManifestCompleted         -SourceIdentifier "$id.manifest" | Out-Null
        Register-ObjectEvent -InputObject $iphm -EventName DownloadProgressChanged      -SourceIdentifier "$id.progress" | Out-Null
        Register-ObjectEvent -InputObject $iphm -EventName DownloadApplicationCompleted -SourceIdentifier "$id.download" | Out-Null

        # 1) Download the manifest
        Write-Verbose "Downloading manifest: $u"
        if ($show) { Write-CoProgress -Activity $activity -Status 'Downloading manifest ...' }
        $iphm.GetManifestAsync()
        $m = Wait-CoEvent "$id.manifest" $null $deadline
        if (-not $m) {
            try { $iphm.CancelAsync() } catch { Write-Verbose "CancelAsync failed: $($_.Exception.Message)" }
            return New-CoResult 'Install' 6 'Timeout' 'Timeout while downloading the manifest.'
        }
        if ($m.Cancelled) { return New-CoResult 'Install' 3 'Cancelled' 'Manifest download was cancelled.' }
        if ($m.Error)     { return New-CoResult 'Install' 3 'ManifestError' $m.Error.Message }
        $info = @{ ProductName = $m.ProductName; Version = "$($m.Version)" }

        # 2) Verify requirements and grant trust without prompting
        if ($show) { Write-CoProgress -Activity $activity -Status "Verifying requirements: $($info.ProductName)" }
        try {
            try { $iphm.AssertApplicationRequirements($true) }
            catch [System.Management.Automation.MethodException] { $iphm.AssertApplicationRequirements() }
        }
        catch { return New-CoResult 'Install' 4 'RequirementsError' $_.Exception.Message $info }

        # 3) Download and install
        if ($show) { Write-CoProgress -Activity $activity -Status "Download: $($info.ProductName)" -Percent 0 }
        $iphm.DownloadApplicationAsync()
        $d = Wait-CoEvent "$id.download" "$id.progress" $deadline -Activity $activity -ShowProgress:$show
        if (-not $d) {
            try { $iphm.CancelAsync() } catch { Write-Verbose "CancelAsync failed: $($_.Exception.Message)" }
            return New-CoResult 'Install' 6 'Timeout' 'Timeout during download/installation.' $info
        }
        if ($d.Cancelled) { return New-CoResult 'Install' 5 'Cancelled' 'Download was cancelled.' $info }
        if ($d.Error)     { return New-CoResult 'Install' 5 'DownloadError' $d.Error.Message $info }

        $info.ShortcutAppId = $d.ShortcutAppId
        $info.LogFilePath   = $d.LogFilePath
        New-CoResult 'Install' 0 'Installed' "Installed: $($info.ProductName) $($info.Version)" $info
    }
    catch {
        New-CoResult 'Install' 1 'Error' $_.Exception.Message
    }
    finally {
        if ($show) { Write-CoProgress -Activity $activity -Completed }
        Get-EventSubscriber -Force -ErrorAction SilentlyContinue | Where-Object SourceIdentifier -like "$id.*" |
            Unregister-Event -Force -ErrorAction SilentlyContinue
        Get-Event -ErrorAction SilentlyContinue | Where-Object SourceIdentifier -like "$id.*" |
            Remove-Event -ErrorAction SilentlyContinue
        if ($iphm) { $iphm.Dispose() }
    }
}
