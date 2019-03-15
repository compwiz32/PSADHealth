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

    
    $config = Get-ADConfig -ConfigurationFile $PSADHealthConfigPath
    
    Switch($PSBoundParameters.Keys){
        'SMTPServer' {
            $config.smtpserver = $SMTPServer
         }
        'Email' {
            $config.email = $Email
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