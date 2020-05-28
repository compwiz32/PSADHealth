function Get-ADLastBackupDate {
    [CmdletBinding()]
    Param()
    <#
    .SYNOPSIS
    Check AD Last Backup Date
    
    .DESCRIPTION
    This script Checks AD for the last backup date

    .EXAMPLE
        PS C:\> $trigger = New-JobTrigger -Once -At 6:00AM -RepetitionInterval (New-TimeSpan -Hours 24) -RepeatIndefinitely
        PS C:\> $cred = Get-Credential DOMAIN\ServiceAccount
        PS C:\> $opt = New-ScheduledJobOption -RunElevated -RequireNetwork
        PS C:\> Register-ScheduledJob -Name Test-ADLastBackupDate -Trigger $trigger -Credential $cred -ScriptBlock {(Import-Module -Name PSADHealth); Test-ADLastBackupDate} -MaxResultCount 5 -ScheduledJobOption $opt

        Creates a scheduled task to run Test-ADLastBackupDate on a daily basis. NOTE: Service account needs to be a Domain Admin or equivalent (Tier0) and must have the RunAsBatch and RunAsService privilege

    .EXAMPLE
    Run in verbose mode if you want on-screen feedback for testing
   
    .NOTES
    Authors: Mike Kanakos, Greg Onstot
    Version: 0.6.3
    Version Date: 04/19/2019
    
    Event Source 'PSMonitor' will be created

    EventID Definition:
    17050 - Failure
    17051 - Beginning of test
    17052 - Successful Test Result
    17053 - End of test
    17054 - Alert Email Sent
    #>

    Begin {
        Import-Module ActiveDirectory -Verbose:$false
        Write-Verbose -Message "Silently loaded ActiveDirectory module"

        $null = Get-ADConfig

        $SupportArticle = $Configuration.SupportArticle

        If (-not ([System.Diagnostics.EventLog]::SourceExists("PSMonitor"))) {
            Write-Verbose -Message "Adding Event Source."
            New-EventLog -LogName Application -Source "PSMonitor"
        } #end if

        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17051 -EntryType Information -message "START of AD Backup Check ." -category "17051"
        
        $Domain = (Get-ADDomain).DNSRoot
        Write-Verbose -Message "Domain: $Domain"
        $Regex = '\d\d\d\d-\d\d-\d\d'
        $CurrentDate = Get-Date
        $MaxDaysSinceBackup = $Configuration.MaxDaysSinceBackup
        Write-Verbose -Message "Maximum allowed days since last backup: $MaxDaysSinceBackup"
        
    }#End Begin

    Process {
        #get the date of last backup from repadmin command using regex
        $LastBackup = (repadmin /showbackup $Domain | Select-String $Regex |ForEach-Object { $_.Matches } | ForEach-Object { $_.Value } )[0]
        #Compare the last backup date to today's date
        $Result = (New-TimeSpan -Start $LastBackup -End $CurrentDate).Days
        
        #Test if result is greater than max allowed days without backup
        If ($Result -gt $MaxDaysSinceBackup) {
            
            Write-Verbose -Message "Last Active Directory backup occurred on $LastBackup! $Result days is higher than the alert criteria of $MaxDaysSinceBackup day."
            
            $emailOutput = "Last Active Directory backup occurred on $LastBackup! $Result days is higher than the alert criteria of $MaxDaysSinceBackup day."
            
            Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17050 -EntryType Warning -message "ALERT - AD Backup is not current.  $emailOutput" -category "17050"
            
            $global:CurrentFailure = $true

            $mailParams = @{
                To = $Configuration.MailTo
                From = $Configuration.MailFrom
                SmtpServer = $Configuration.SmtpServer
                Subject = "AD Backup Check Alert! Backup is $Result days old"
                Body = $emailOutput
                BodyAsHtml = $true
          }

          Send-MailMessage @mailParams
          Write-Verbose -Message "Sent email notification for Last AD Backup Date"
          #Write-Verbose "Sending Slack Alert"
          #New-SlackPost "Alert - AD Last Backup is $Result days old"
        }else {
            Write-Verbose -Message "Last Active Directory backup occurred on $LastBackup! $Result days is less than the alert criteria of $MaxDaysSinceBackup day."
            Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17052 -EntryType Information -message "SUCCESS - Last Active Directory backup occurred on $LastBackup! $Result days is less than the alert criteria of $MaxDaysSinceBackup day." -category "17052"
        }#end else
        
    
    }#End Process
    
    End {
        
        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17053 -EntryType Information -message "END of AD Backup Check ." -category "17053"
        
        If (!$CurrentFailure){
            Write-Verbose -Message "No Issues found in this run"
            $InError = Get-EventLog application -After (Get-Date).AddHours(-24) | Where-Object {($_.InstanceID -Match "17050")} 
            
            If ($InError) {
                Write-Verbose -Message "Previous Errors Seen"
                #Previous run had an alert
                #No errors foun during this test so send email that the previous error(s) have cleared
                $alertclearedParams = @{
                    To = $Configuration.MailTo
                    From = $Configuration.MailFrom
                    SmtpServer = $Configuration.SmtpServer
                    Subject = "AD Internal Time Sync - Alert Cleared!"
                    Body = "The previous Internal AD Time Sync alert has now cleared."
                    BodyAsHtml = $true
              }
    
              Send-MailMessage @alertclearedParams
              Write-Verbose -Message "Sent email notification for Last AD Backup Date Recovery"
              #Write-Verbose "Sending Slack Message - AD Backup Alert Cleared"
              #New-SlackPost "The previous alert, for AD Last Backup has cleared."
                #Write-Output $InError
            }#End if
        
        }#End if

    }#End End

}#End Function
