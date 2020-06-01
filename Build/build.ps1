[CmdletBinding()]
param(
    [switch]
    $Bootstrap,

    [switch]
    $Compile,

    [switch]
    $Test,

    [switch]
    $Deploy

)

# Bootstrap step
if ($Bootstrap.IsPresent) {
    Write-Information "Validate and install missing prerequisits for building ..."

    # For testing Pester
    if (-not (Get-Module -Name Pester -ListAvailable)) {
        Write-Warning "Module 'Pester' is missing. Installing 'Pester' ..."
        Install-Module -Name Pester -Scope CurrentUser -Force
    }

    # For tweeting
    if (-not (Get-Module -Name PSTwitterAPI -ListAvailable)) {
        Write-Warning "Module 'PSTwitterAPI' is missing. Installing 'PSTwitterAPI' ..."
        Install-Module -Name PSTwitterAPI -Scope CurrentUser -Force
    }

}

# Compile step
if ($Compile.IsPresent) {
    if (Get-Module PSADHealth) {
        Remove-Module PSADHealth -Force
    }

    if ((Test-Path .\Output)) {
        Remove-Item -Path .\Output -Recurse -Force
    }

    # Copy non-script files to output folder
    if (-not (Test-Path .\Output)) {
        $null = New-Item -Path .\Output -ItemType Directory
    }

    Copy-Item -Path '.\PSADHealth\*' -Filter '*.*' -Exclude '*.ps1', '*.psm1' -Recurse -Destination .\Output -Force
    Remove-Item -Path .\Output\Private, .\Output\Public -Recurse -Force

    # Copy Module README file
    Copy-Item -Path '.\README.md' -Destination .\Output -Force

    Get-ChildItem -Path ".\PSADHealth\Private\*.ps1" -Recurse | Get-Content | Add-Content .\Output\PSADHealth.psm1

    $Public  = @( Get-ChildItem -Path ".\PSADHealth\Public\*.ps1" -ErrorAction SilentlyContinue )

    $Public | Get-Content | Add-Content .\Output\PSADHealth.psm1


    "`$PublicFunctions = '$($Public.BaseName -join "', '")'" | Add-Content .\Output\PSADHealth.psm1

    #Let's add New-TaskRegistration.ps1 as part of Non-Module Scripts that get published with the module
    Copy-Item -Path '.\Non-Module Scripts\*' -Filter '*.*' -Destination '.\Output\Non-Module Scripts' -Force

    Remove-Item -Path .\PSADHealth -Recurse -Force
    Rename-Item -Path .\Output -NewName 'PSADHealth'

    # Compress output, for GitHub release
    Compress-Archive -Path .\PSADHealth\* -DestinationPath .\Build\PSADHealth.zip

    # Re-import module, extract release notes and version
    Import-Module .\PSADHealth\PSADHealth.psd1 -Force
    (Get-Module PSADHealth)[0].ReleaseNotes | Add-Content .\Build\release-notes.txt
    (Get-Module PSADHealth)[0].Version.ToString() | Add-Content .\Build\release-version.txt

}

# Test step
if($Test.IsPresent) {
    if (-not (Get-Module -Name Pester -ListAvailable)) {
        throw "Cannot find the 'Pester' module. Please specify '-Bootstrap' to install build dependencies."
    }

    Install-Module -Name Pester -RequiredVersion 4.3.1 -Scope CurrentUser -Force -SkipPublisherCheck

    $RelevantFiles = (Get-ChildItem $PSScriptRoot -Recurse -Include "*.psm1","*.ps1").FullName

    if ($env:TF_BUILD) {
        $res = Invoke-Pester ".\Test" -OutputFormat NUnitXml -OutputFile TestResults.xml -CodeCoverage $RelevantFiles -PassThru
        if ($res.FailedCount -gt 0) { throw "$($res.FailedCount) tests failed." }
    } else {
        $res = Invoke-Pester ".\Test\Validation.Tests.ps1" -PassThru
    }

}

#Deploy step
if($Deploy.IsPresent) {

    Try {
        $Splat = @{
            Path        = (Resolve-Path -Path .\PSADHealth)
            NuGetApiKey = $env:NugetAPIKey
            ErrorAction = 'Stop'
        }
        Publish-Module @Splat


        Write-Output -InputObject ('PSADHealth PowerShell Module published to the PowerShell Gallery')

    } Catch {
        throw $_
    }
}
