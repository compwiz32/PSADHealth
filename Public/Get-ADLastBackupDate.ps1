function Get-ADLastBackupDate {
    [CmdletBinding()]
    Param()
    <#
    .SYNOPSIS
    Check AD Last Backup Date
    
    .DESCRIPTION
    This script Checks AD for the last backup date

    .EXAMPLE
    Run as a scheduled task.  Use Event Log consolidation tools to pull and alert on issues found.

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
        Import-Module activedirectory

        $null = Get-ADConfig

        $SupportArticle = $Configuration.SupportArticle

        if (![System.Diagnostics.EventLog]::SourceExists("PSMonitor")) {
            write-verbose "Adding Event Source."
            New-EventLog -LogName Application -Source "PSMonitor"
        }#end if

        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17051 -EntryType Information -message "START of AD Backup Check ." -category "17051"
        
        $Domain = (Get-ADDomain).DNSRoot
        $Regex = '\d\d\d\d-\d\d-\d\d'
        $CurrentDate = Get-Date
        $MaxDaysSinceBackup = $Configuration.MaxDaysSinceBackup
        
    }#End Begin

    Process {
        #get the date of last backup from repadmin command using regex
        $LastBackup = (repadmin /showbackup $Domain | Select-String $Regex |ForEach-Object { $_.Matches } | ForEach-Object { $_.Value } )[0]
        #Compare the last backup date to today's date
        $Result = (New-TimeSpan -Start $LastBackup -End $CurrentDate).Days
        
        Write-Verbose "Last Active Directory backup occurred on $LastBackup! $Result days is less than the alert criteria of $MaxDaysSinceBackup day."
                        
        #Test if result is greater than max allowed days without backup
        If ($Result -gt $MaxDaysSinceBackup) {
            
            Write-Verbose "Last Active Directory backup occurred on $LastBackup! $Result days is higher than the alert criteria of $MaxDaysSinceBackup day."
            
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
          #Write-Verbose "Sending Slack Alert"
          #New-SlackPost "Alert - AD Last Backup is $Result days old"
        }else {
            Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17052 -EntryType Information -message "SUCCESS - Last Active Directory backup occurred on $LastBackup! $Result days is less than the alert criteria of $MaxDaysSinceBackup day." -category "17052"
        }#end else
        
    
    }#End Process
    
    End {
        
        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17053 -EntryType Information -message "END of AD Backup Check ." -category "17053"
        
        If (!$CurrentFailure){
            Write-Verbose "No Issues found in this run"
            $InError = Get-EventLog application -After (Get-Date).AddHours(-24) | where {($_.InstanceID -Match "17050")} 
            
            If ($InError) {
                Write-Verbose "Previous Errors Seen"
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
              #Write-Verbose "Sending Slack Message - AD Backup Alert Cleared"
              #New-SlackPost "The previous alert, for AD Last Backup has cleared."
                #Write-Output $InError
            }#End if
        
        }#End if

    }#End End

}#End Function