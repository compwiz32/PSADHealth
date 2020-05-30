function Set-PSADHealthConfig
{
    <#
        .SYNOPSIS
        Sets the configuration data for this module

        .PARAMETER PSADHealthConfigPath

        The filesystem location to store configuration file data.

        .PARAMETER SMTPServer

        The smtp server this module will use for reports.

        .PARAMETER ExternalDNSServers

        Provide an array of servers: @('1.2.3.4', '4.3.2.1')

        .EXAMPLE
        Set-PSADHealthConfig -SMTPServer email.company.com

        .EXAMPLE
        Set-PSADHealthConfig -MailFrom admonitor@foobar.come -MailTo directoryadmins@foobar.com

        .EXAMPLE
        Set-PSADHealthConfig -MaxDaysSinceBackup 12

        .NOTES
        Updated: 05/29/2020
            Added FreeDiskThreshold parameter and setting update
            Added ExternalDNSServers parameter, setting update and PARAMETER help message
            Modified assignment to PSADHealthConfigPath parameter so that it will work with Public folder during development (and should still work fine in production)
    #>

    [cmdletBinding()]
    Param(

        [Parameter(Position=0)]
        $PSADHealthConfigPath = ("$($PSScriptRoot)\Config\ADConfig.json").Replace('Public\',''),

        [Parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]
        $SMTPServer = "mail.server.fqdn",

        [Parameter()]
        [String]
        $MailFrom,

        [Parameter()]
        [String[]]
        $MailTo,

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
        [array]
        $ExternalDNSServers,

        [Parameter()]
        [Int]
        $FreeDiskThreshold,

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

    
    $config = Get-ADConfig -ConfigurationFile $PSADHealthConfigPath
    
    Switch($PSBoundParameters.Keys){
        'SMTPServer' {
            $config.smtpserver = $SMTPServer
         }
        'MailFrom' {
            $config.MailFrom = $MailFrom
        }
        'MailTo' {
            $config.MailTo = $MailTo
        }
        'MaxDaysSinceBackup' {
            $config.MaxDaysSinceBackup = $MaxDaysSinceBackup
        }
        'MaxIntTimeDrift' {
            $config.MaxIntTimeDrift = $MaxIntTimeDrift
        }
        'MaxExtTimeDrift' {
            $config.MaxExtTimeDrift = $MaxExtTimeDrift
        }
        'ExternalTimeServer' {
            $config.ExternalTimeSvr = $ExternalTimeServer
        }
        'ExternalDNSServers' {
            $config.ExternalDNSServers = $ExternalDNSServers
        }
        'FreeDiskThreshold' {
            $config.FreeDiskThreshold = $FreeDiskThreshold
        }
        'MaxObjectReplCycles' {
            $config.MaxObjectReplCycles = $MaxObjectReplCycles
        }
        'MaxSysvolReplCycles' {
            $config.MaxSysvolReplCycles = $MaxSysvolReplCycles
        }
        'SupportArticleUrl' {
            $config.SupportArticle = $SupportArticleUrl
        }
        'SlackToken' {
            $config.SlackToken = $SlackToken
        }

    }
    
    $config | ConvertTo-Json | Set-Content $PSADHealthConfigPath
	
}
