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
        Email = @('test@fqdn.com')
        MaxDaysSinceBackup = '1'
        MaxIntTimeDrift = '45'
        MaxExtTimeDrift = '15'
        ExternalTimeSvr = 'time.fqdn'
        MaxObjectReplCycles = '50'
        MaxSysvolReplCycles = '50'
        SupportArticle  = "https://<YourServer/YourTroubleshootingArticles>"
        SlackToken = '<SlackAPIToken>'

    }

    [pscustomobject]$obj | ConvertTo-Json | Add-Content $PSADHealthConfigPath

}