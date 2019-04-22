function Set-PSADHealthConfig
{
    <#
        .SYNOPSIS
        Sets the configuration data for this module

        .PARAMETER PSADHealthConfigPath

        The filesystem location to store configuration file data.

        .PARAMETER SMTPServer

        The smtp server this module will use for reports.

        .EXAMPLE
        Set-PSADHealthConfig -SMTPServer email.company.com

        .EXAMPLE
        Set-PSADHealthConfig -MailFrom admonitor@foobar.come -MailTo directoryadmins@foobar.com

        .EXAMPLE
        Set-PSADHealthConfig -MaxDaysSinceBackup 12


    #>

    [cmdletBinding()]
    Param(

        [Parameter(Position=0)]
        $PSADHealthConfigPath = "$(Split-Path $PSScriptRoot)\Config\ADConfig.json",

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