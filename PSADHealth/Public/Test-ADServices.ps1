# Test-ADServices.ps1
function Test-ADServices {
    [cmdletBinding()]
    Param()
    <#
    .SYNOPSIS
    Monitor AD Domain Controller Services

    .DESCRIPTION
    This function is used to Monitor AD Domain Controller services and send alerts if any identified services are stopped

    .EXAMPLE
    Run as a scheduled task on a tool server to remotely monitor service status on all DCs in a specified domain.

    .EXAMPLE
    PS C:\> $trigger = New-JobTrigger -Once -At 6:00AM -RepetitionInterval (New-TimeSpan -Hours 1) -RepeatIndefinitely
    PS C:\> $cred = Get-Credential DOMAIN\ServiceAccount
    PS C:\> $opt = New-ScheduledJobOption -RunElevated -RequireNetwork
    PS C:\> Register-ScheduledJob -Name Test-ADServices -Trigger $trigger -Credential $cred -ScriptBlock {(Import-Module -Name PSADHealth); Test-ADServices} -MaxResultCount 5 -ScheduledJobOption $opt

    Creates a scheduled task to run Test-ADServices on a hourly basis. NOTE: Service account needs to be a Domain Admin or equivalent (Tier0) and must have the RunAsBatch and RunAsService privilege

    .NOTES
    Authors: Mike Kanakos, Greg Onstot
    Version: 0.0.5
    Version Date: 10/30/2019

#>
    begin {
        Import-Module ActiveDirectory -Verbose:$false
        Write-Verbose -Message "Silently loaded ActiveDirectory module"
        #Creates a global $configuration variable
        $null = Get-ADConfig
        $DClist = (Get-ADGroupMember "Domain Controllers").name
        Write-Verbose -Message "DCList: $DCList"
        $Collection = @('ADWS',
            'DHCPServer',
            'DNS',
            'DFS',
            'DFSR',
            'Eventlog',
            'EventSystem',
            'KDC',
            'LanManWorkstation',
            'LanManServer',
            'NetLogon',
            'NTDS',
            'RPCSS',
            'SAMSS',
            'W32Time')
        Write-Verbose -Message "Services to test: $Collection"
        $ServiceFilter = ($Collection | ForEach-Object { "name='$_'" }) -join " OR "
        $ServiceFilter = "State='Stopped' and ($ServiceFilter)"
        Write-Verbose -Message "ServiceFilter: $ServiceFilter"
    }

    process {
        try {
            Write-Verbose -Message "Querying all Domain Controllers for Filtered list of essential services"
            $services = Get-CimInstance Win32_Service -filter $ServiceFilter -Computername $DClist -ErrorAction Stop -Verbose:$false
            Write-Verbose -Message "Finished querying all Domain Controllers"
        }
        catch {
            Out-Null
            Write-Verbose -Message "Failed to query any of the servers. Get-CimInstance didn't work"
        }

        foreach ($service in $services) {
            $Subject = "Windows Service: $($service.Displayname), is stopped on $($service.PSComputerName)"
                $EmailBody = @"
                            Service named <font color=Red><b>$($service.Displayname)</b></font> is stopped!
                            Time of Event: <font color=Red><b>"""$((get-date))"""</b></font><br/>
                            <br/>
                            THIS EMAIL WAS AUTO-GENERATED. PLEASE DO NOT REPLY TO THIS EMAIL.
"@
                $mailParams = @{
                    To         = $Configuration.MailTo
                    From       = $Configuration.MailFrom
                    SmtpServer = $Configuration.SmtpServer
                    Subject    = $Subject
                    Body       = $EmailBody
                    BodyAsHtml = $true
                }
                Send-MailMessage @mailParams
                Write-Verbose -Message "Sent email notification for stopped service ($($service.DisplayName)) on $($service.PSComputerName)"
        }
    } #Process
} #function
