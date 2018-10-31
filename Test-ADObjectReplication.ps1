function Test-ADObjectReplication {
    [CmdletBinding()]
    Param()
    <#
    .SYNOPSIS
    Monitor AD Object Replication
    
    .DESCRIPTION
    Each run of the script creates a unique test object (a disabled computer account) in the domain, and tracks it's replication to all other DCs in the domain.
    By default it will query the DCs for about 60 minutes.  If after 50 loops the object hasn't repliated the test will terminate and create an alert.

    .EXAMPLE
    Run as a scheduled task.  Use Event Log consolidation tools to pull and alert on issues found, and/or when the scheduled task fails to run.
    $cred = Get-Credential -Credential <Domain>\<ServiceAccount>
    $opt = New-ScheduledJobOption -RunElevated -RequireNetwork
    $trigger = New-JobTrigger -Once -At 6:00AM -RepetitionInterval (New-TimeSpan -Hours 2) -RepeatIndefinitely
    Register-ScheduledJob -Name Test-ADObjectReplication -Trigger $trigger -Credential $cred -FilePath "C:\Scripts\Test-ADObjectReplication.ps1" -MaxResultCount 5 -scheduledjoboption $opt

    .EXAMPLE
    Run in verbose mode if you want on-screen feedback for testing
    Test-ADObjectReplication -Verbose
   
    .NOTES
    Author: Greg Onstot
    Version: 0.2
    Version Date: 10/29/2018

    This script must be run from a Win10, or Server 2016 system.  It can target older OS Versions.

    Event Source 'PSMonitor' will be created

    EventID Definition:
    17010 - Failure
    17011 - Cycle Count
    17012 - Test Object not yet on DC
    17013 - Test Object on DC
    17014 - Tests didn't complete in alloted time span
    17015 - Job output
    17016 - Test Object Created
    17017 - Test Object Deleted
    17018 - 1 minute Sleep
    17019 - Posible old object detected
    #>

    Begin {
        #Import-Module activedirectory
        if (![System.Diagnostics.EventLog]::SourceExists("PSMonitor")) {
            write-verbose "Adding Event Source."
            New-EventLog –LogName Application –Source "PSMonitor"
        }
        $continue = $true
        $existingObj = $null
        $DCs = (Get-ADDomainController -Filter *).Name 
        $SourceSystem = (Get-ADDomain).pdcemulator
        [int]$MaxCycles = 50        
    }

    Process {
        if (Test-NetConnection $SourceSystem -Port 445 -InformationLevel Quiet) {
            Write-Verbose 'PDCE is online'
            $tempObjectPath = (Get-ADDomain).computersContainer
            $existingObj = Get-ADComputer -filter 'name -like "ADRT-*"' -prop * -SearchBase "$tempObjectPath" |Select-Object -ExpandProperty Name
            If ($existingObj) {
                Write-Verbose "Warning - Cleanup of a old object(s) may not have occured.  Object(s) starting with 'ADRT-' exists in $tempObjectPath : $existingObj  - Please review, and cleanup if required."
                Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17019 -EntryType Warning -message "Warning - Cleanup of old object(s) may not have occured.  Object(s) starting with 'ADRT-' exists in $tempObjectPath : $existingObj.  Please review, and cleanup if required." -category "17019"
            }

            $site = (Get-ADDomainController $SourceSystem).site
            $startDateTime = Get-Date
            [string]$tempObjectName = "ADRT-" + (Get-Date -f yyyyMMddHHmmss)
            
            New-ADComputer -Name "$tempObjectName" -samAccountName "$tempObjectName" -Path "$tempObjectPath" -Server $SourceSystem -Enabled $False
            
            Write-Verbose "Object created for tracking - $tempObjectName in $site"
            Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17016 -EntryType Information -message "Test object - $tempObjectName  - has been created on $SourceSystem in site - $site" -category "17016"
            $i = 0
        }
        else {
            Write-Verbose 'PDCE is offline.  You should really resolve that before continuing.'
            Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17010 -EntryType Error -message "FAILURE! - Failed to connect to PDCE - $SourceSystem  in site - $site" -category "17010"
            break
        }

        While ($continue) {
            $i++
            Write-Verbose 'Sleeping for 1 minute.'
            Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17018 -EntryType Information -message "Sleeping for 1 minute" -category "17018"
            Start-Sleep 60
            $replicated = $true
            Write-Verbose "Cycle - $i"
            Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17011 -EntryType Information -message "ADRepl Cycle $i" -category "17011"
        
            Foreach ($dc in $DCs) {
                $site = (Get-ADDomainController $dc).site
                if (Test-NetConnection $dc -Port 445 -InformationLevel Quiet) {
                    Write-Verbose "Online - $dc"
                    $connectionResult = "SUCCESS"
                }
                else {
                    Write-Verbose "!!!!!OFFLINE - $dc !!!!!"
                    $connectionResult = "FAILURE"
                    Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17010 -EntryType Error -message "Failed to connect to DC - $dc in site - $site" -category "17010"
                }

                # If The Connection To The DC Is Successful
                If ($connectionResult -eq "SUCCESS") {
                    Try {	
                        $Milliseconds = (Measure-Command {$Query = Get-ADComputer $tempObjectName -Server $dc | select Name}).TotalMilliseconds
                        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17013 -EntryType information -message "SUCCESS! - Test object replicated to - $dc in site - $site - in $Milliseconds ms. " -category "17013"
                        write-Verbose "SUCCESS! - Replicated -  $($query.Name) - $($dc) - $site - $Milliseconds"
                    }
                    Catch {
                        write-Verbose "PENDING! - Test object $tempObjectName does not exist on $dc in $site."
                        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17012 -EntryType information -message "PENDING! - Test object pending replication to - $dc in site - $site. " -category "17012"
                        $replicated = $false
                    }    
                }
        		
                # If The Connection To The DC Is Unsuccessful
                If ($connectionResult -eq "FAILURE") {
                    Write-Verbose "     - Unable To Connect To DC/GC And Check For The Temp Object..."
                    Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17010 -EntryType Error -message "FAILURE! - Failed to connect to DC - $dc in site - $site" -category "17010"
                }
            }

            If ($replicated) {
                $continue = $false
            } 

            If ($i -gt $MaxCycles) {
                $continue = $false
                Write-Verbose "Cycle has run $i times, and replication hasn't finished.  Need to generate an alert."
                Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17014 -EntryType Warning -message "TIMEOUT! - Test cycle has run $i times without the object succesfully replicating to all DCs" -category "17014"
                $domainname = (Get-ADDomain).dnsroot
                $Alert = "In $domainname - the AD Replication Test cycle has run $i times without the object succesfully replicating to all DCs.  Please investigate."
                Send-Mail $Alert
            } 
        }
    }

    End {
        # Show The Start Time, The End Time And The Duration Of The Replication
        $endDateTime = Get-Date
        $duration = "{0:n2}" -f ($endDateTime.Subtract($startDateTime).TotalSeconds)
        $output = "`n  Start Time......: $(Get-Date $startDateTime -format "yyyy-MM-dd HH:mm:ss")"
        $output = $output + "`n  End Time........: $(Get-Date $endDateTime -format "yyyy-MM-dd HH:mm:ss")"
        $output = $output + "`n  Duration........: $duration Seconds"
        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17015 -EntryType Information -message "Test cycle has Ended - $output" -category "17015"
        
        Write-Verbose "`n  Start Time......: $(Get-Date $startDateTime -format "yyyy-MM-dd HH:mm:ss")"
        Write-Verbose "  End Time........: $(Get-Date $endDateTime -format "yyyy-MM-dd HH:mm:ss")"
        Write-Verbose "  Duration........: $duration Seconds"
        
        # Delete The Temp Object On The RWDC
        Write-Verbose "  Deleting AD Object File..."
        Remove-ADComputer $tempObjectName -Confirm:$False
        Write-Verbose "  AD Object [$tempObjectName] Has Been Deleted."
        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17017 -EntryType Information -message "Test object - $tempObjectName  - has been deleted." -category "17017"
    }
}

function Send-Mail {
    Param($Alert)
    Write-Verbose "Sending Email"
    Write-Verbose "Output is --  $Alert"
    
    #Mail Server Config
    $NBN = (Get-ADDomain).NetBIOSName
    $domainname = (Get-ADDomain).dnsroot
    $smtpServer = "<SMTPSERVER>.$Domainname"
    $smtp = new-object Net.Mail.SmtpClient($smtpServer)
    $msg = new-object Net.Mail.MailMessage

    #Send to list:    
    $msg.To.Add("<TargetUSER>@$domainname")
    $msg.To.Add("<TargetDL>@$domainname")
    
    #Message:
    $msg.From = "ADOBJECTREPL-$NBN@$domainname"
    $msg.ReplyTo = "ADOBJECTREPL-$NBN@$domainname"
    $msg.subject = "$NBN AD Object Replication Failure!"
    $msg.body = $Alert

    #Send it
    $smtp.Send($msg)
}


Test-ADObjectReplication #-Verbose