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
        $PSADHealthConfigPath = "$env:HOMEPATH\ADConfig.json",

        [Parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]
        $SMTPServer = "mail.server.fqdn",

        [Parameter()]
        [String[]]
        $Email,

        [Parameter()]
        [String]
        $MaxDaysSinceBackup,

        [Parameter()]
        [Int]
        $MaxIntTimeDrift,

        [Parameter()]
        [Int]
        $MaxExtTimeDrift,

        [Parameter()]
        [string]
        $ExternalTimeServer,

        [Parameter()]
        [Int]
        $MaxObjectReplCycles,

        [Parameter()]
        [Int]
        $MaxSysvolReplCycles,

        [Parameter()]
        [String]
        $SupportArticleUrl,

        [Parameter()]
        [String]
        $SlackToken
    )

    
    $obj = @{

        SMTPServer = $SMTPServer
        Email = $Email
        MaxDaysSinceBackup = $MaxDaysSinceBackup
        MaxIntTimeDrift = $MaxIntTimeDrift
        MaxExtTimeDrift = $MaxExtTimeDrift
        ExternalTimeSvr = $ExternalTimeServer
        MaxObjectReplCycles = $MaxObjectReplCycles
        MaxSysvolReplCycles = $MaxSysvolReplCycles
        SupportArticle  = $SupportArticleUrl
        SlackToken = $SlackToken

    }

    [pscustomobject]$obj | ConvertTo-Json | Add-Content $PSADHealthConfigPath

}