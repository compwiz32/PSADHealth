function Set-PSADHealthConfig
{
    <#
        .SYNOPSIS
        Sets the configuration data for this module

        .PARAMETER PSADHealthConfigPath

        The filesystem location to store configuration file data.

        .PARAMETER SMTPServer

        The smtp server this module will use for reports.


    #>

    [cmdletBinding()]
    Param(

        [Parameter(Position=0)]
        [ValidateScript({Test-Path $_ -Type Container})]
        $PSADHealthConfigPath = $env:HOME,

        [Parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]
        $SMTPServer = "mail.server.fqdn"
    )

    
    $obj = @{

        SMTPServer = $SMTPServer

    }

    [pscustomobject]$obj | ConvertTo-Json | Add-Content $PSADHealthConfigPath



}