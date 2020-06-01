Function Test-DCsOnline {
    <#
    .SYNOPSIS
        Simple connection test to all domain controllers to verify they are online

    .DESCRIPTION
        Simple connection test to all domain controllers to verify they are online

    .EXAMPLE
        PS C:\> Test-DCsOnline
        
        This will silently test all Domain Controllers are online and only email notification if there is a failure

    .EXAMPLE
        PS C:\> Test-DCsOnline -Verbose
        
        This will provide a status while testing from all Domain Controllers and only email notification if there is a failure
        In the event of a Ping and/or TCP-53 test failure, there will be a warning messages displayed in the console when interactive
    .EXAMPLE
        PS C:\> $trigger = New-JobTrigger -Once -At 6:00AM -RepetitionInterval (New-TimeSpan -Hours 1) -RepeatIndefinitely
        PS C:\> $cred = Get-Credential DOMAIN\ServiceAccount
        PS C:\> $opt = New-ScheduledJobOption -RunElevated -RequireNetwork
        PS C:\> Register-ScheduledJob -Name Test-DCsOnline -Trigger $trigger -Credential $cred -ScriptBlock {(Import-Module -Name PSADHealth); Test-DCsOnline} -MaxResultCount 5 -ScheduledJobOption $opt

        Creates a scheduled task to run Test-DCsOnline on an hourly basis. NOTE: Service account needs to be a Domain Admin or equivalent (Tier0) and must have the RunAsBatch and RunAsService privilege
    .NOTES

    #>
    [cmdletBinding()]
    Param()

    Begin {
        Import-Module ActiveDirectory -Verbose:$false
        Write-Verbose -Message "Silently loaded ActiveDirectory module"
        #Creates a global $configuration variable
        $null = Get-ADConfig
    }

    Process {
        $DClist = (get-adgroupmember "Domain Controllers").name
        Write-Verbose -Message "DCList: $DCList"

        ForEach ($server in $DClist){
            Write-Verbose -Message "Testing $server is online"

            if  ((-not (Test-Connection -ComputerName $Server -quiet -count 4)))
            {
                $Subject = "Server $Server is offline"
                $EmailBody = @"


        Server named <font color="Red"><b> $Server </b></font> is offline!
        Time of Event: <font color="Red"><b> $((get-date))</b></font><br/>
        <br/>
        THIS EMAIL WAS AUTO-GENERATED. PLEASE DO NOT REPLY TO THIS EMAIL.
"@

                $mailParams = @{
                    To = $Configuration.MailTo
                    From = $Configuration.MailFrom
                    SmtpServer = $Configuration.SmtpServer
                    Subject = $Subject
                    Body = $EmailBody
                    BodyAsHtml = $true
                }
                Send-MailMessage @mailParams
                Write-Verbose -Message "Sent email notification for failed DC online test"

            } #End if
        }#End Foreach
    }
    End {
        Write-Verbose -Message "Finished verifying all DCs are online"
    }
}