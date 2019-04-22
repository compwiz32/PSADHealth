function Get-ADConfig {
    <#
        .SYNOPSIS
        Converts json config data into usable powershell object

        .PARAMETER Configuration

        Location of the json file which hold module configuration data
        .EXAMPLE

        Get-ADConfig "C:\configs\ADConfig.json"


    #>
    [cmdletBinding()]
    [Alias('Get-ADHealthConfig')]
    Param(
        [Parameter(Position=0)]
        [ValidateScript({ Test-Path $_})]
        [String]
        $ConfigurationFile = "$(Split-Path $PSScriptRoot)\Config\ADConfig.json"
    )

    begin {}

    process {

        $Global:Configuration = Get-Content $ConfigurationFile | ConvertFrom-JSON

        $Configuration
    }

    end {}

}