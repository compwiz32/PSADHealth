function Get-ADConfig {
    <#
        .SYNOPSIS
        Converts json config data into usable powershell object

        .PARAMETER Configuration

        Location of the json file which hold module configuration data
        .EXAMPLE

        Get-ADConfig "C:\configs\ADConfig.json"

        .NOTES
        Added configuration file location test to ease testing of individual functions
    #>
    [cmdletBinding()]
    [Alias('Get-ADHealthConfig')]
    Param(
        [Parameter(Position=0)]
        [ValidateScript({ Test-Path $_})]
        [String]
        $ConfigurationFile = "$PSScriptRoot\Config\ADConfig.json"
    )

    begin {
        Write-Verbose -Message "Verifying Configuration File Path valid: $ConfigurationFile"
        If (-not (Test-Path -Path $ConfigurationFile)) {
            #When testing the module during development, the default pathing doesn't work
            $ConfigurationFile = $ConfigurationFile.Replace('Public\', '')
            If (Test-Path -Path $ConfigurationFile) {
                Write-Verbose -Message "Configuration path updated: $ConfigurationFile"
            } else {
                Write-Warning -Message "Unable to find configuration File!!!"
            }
        }
    }

    process {

        $Global:Configuration = Get-Content $ConfigurationFile | ConvertFrom-JSON

        $Configuration
    }

    end {}

}