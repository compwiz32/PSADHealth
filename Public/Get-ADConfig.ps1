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
    Param(
        [Parameter(Mandatory,Position=0)]
        [ValidateScript({ Test-Path $_})]
        [String]
        $Configuration = "$PSScriptRoot\Public\ADConfig.json"
    )

    begin {}

    process {

        $Global:Configuration | ConvertFrom-JSON $Configuration

    }

    end {}

}