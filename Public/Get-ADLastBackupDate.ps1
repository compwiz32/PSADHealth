# Get-ADLastBackupDate.ps1

function Get-ADLastBackupDate {
    [CmdletBinding()]
    Param()

    
    <#
    .SYNOPSIS
        Check AD Last Backup Date
    
    .DESCRIPTION
        This script Checks AD for the last backup date


    .NOTES
        Authors: Mike Kanakos, Greg Onstot
        Version: 0.6
        Version Date: 11/19/2018
    #>

    Begin {
        Import-Module activedirectory
        $null = Get-ADConfig
        
    }


    Process {
        $Domain = (Get-ADDomain).DNSRoot
        $Regex =  '\d\d\d\d-\d\d-\d\d'
        $CurrentDate = Get-Date
        $MaxDaysSinceBackup = '1'
    
    

        #get the date of last backup from repadmin command using regex
        $LastBackup = (repadmin /showbackup $Domain | Select-String $Regex | foreach { $_.Matches } | foreach { $_.Value } )[0]

        #Compare the last backup date to today's date
        $Result = (NEW-TIMESPAN –Start $LastBackup -End $CurrentDate).Days
            
        #Test if result is greater than max allowed days without backup
        If ($Result -gt $MaxDaysSinceBackup){

            $Subject = "Last Active Directory backup occurred on $LastBackup!"
            $EmailBody = @"
            
        
            The last time Active Directory was backed up was on <font color="Red"><b> $LastBackup </b></font> 
            which was <font color="Red"><b> $Result</b></font> days ago.
            
            You asked to be alerted when backups are not completed for more that $MaxDaysSinceBackup days!
            Time of Event: <font color="Red"><b> $(get-date) </b></font><br/>
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
            } # end Mailparams

            Send-MailMessage @mailParams


        #  Send-MailMessage -To $MailTo -From $MailSender -SmtpServer $SMTPServer 
        # -Subject $Subject -Body $EmailBody -BodyAsHtml

        } #End if

    } #end process

    End { }

} #end function