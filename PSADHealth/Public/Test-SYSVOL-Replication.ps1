<#A simplified re-write of a script published by Jorge de Almeida Pinto, to be used primarily for non-interactive monitoring/alerting.

The original can be found here:
https://jorgequestforknowledge.wordpress.com/2014/02/17/testing-sysvol-replication-latencyconvergence-through-powershell-update-3/

#>

function Test-SysvolReplication {
    [CmdletBinding()]
    Param()
    <#
    .SYNOPSIS
    Monitor AD SYSVOL Replication
    
    .DESCRIPTION
    Each run of the script creates a unique test object in SYSVOL on the PDCE, and tracks it's replication to all other DCs in the domain.
    By default it will query the DCs for about 60 minutes.  If after 60 loops the file hasn't repliated the test will terminate and create an alert.

    .EXAMPLE
    Run as a scheduled task.  Use Event Log consolidation tools to pull and alert on issues found.

    .EXAMPLE
    Run in verbose mode if you want on-screen feedback for testing
   
    .NOTES
    Author Greg Onstot
    This script must be run from a Win10, or Server 2016 system.  It can target older OS Versions.
    Version: 0.6.5
    Version Date: 4/18/2019
    
    Event Source 'PSMonitor' will be created

    EventID Definition:
    17000 - Failure
    17001 - Cycle Count
    17002 - Test Object not yet on DC
    17003 - Test Object on DC
    17004 - Tests didn't complete in alloted time span
    17005 - Job output
    17006 - Test Object Created
    17007 - Test Object Deleted
    17008 - 1 minute Sleep
    17009 - Alert Email Sent
    #>

    Begin {
        Import-Module activedirectory
        $null = Get-ADConfig
        $SupportArticle = $Configuration.SupportArticle
        if (![System.Diagnostics.EventLog]::SourceExists("PSMonitor")) {
            write-verbose "Adding Event Source."
            New-EventLog -LogName Application -Source "PSMonitor"
        }
        $continue = $true
        $CurrentFailure = $false
        $domainname = (Get-ADDomain).dnsroot
        $DCList = (Get-ADDomainController -Filter *).name
        $SourceSystem = (Get-ADDomain).pdcemulator
        [int]$MaxCycles = $Configuration.MaxSysvolReplCycles
    }
    
    Process {
        if (Test-NetConnection $SourceSystem -Port 445) {
            Write-Verbose 'PDCE is online'
            $TempObjectLocation = "\\$SourceSystem\SYSVOL\$domainname\Scripts"
            $tempObjectName = "sysvolReplTempObject" + (Get-Date -f yyyyMMddHHmmss) + ".txt"
            $objectPath = "\\$SourceSystem\SYSVOL\$domainname\Scripts\$tempObjectName"
            "...!!!...TEMP OBJECT TO TEST AD REPLICATION LATENCY/CONVERGENCE...!!!..." | Out-File -FilePath $($TempObjectLocation + "\" + $tempObjectName)
            $site = (Get-ADDomainController $SourceSystem).site

            Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17006 -EntryType Information -message "CREATE SYSVOL Test object - $tempObjectName  - has been created on $SourceSystem in site - $site" -category "17006"
            Start-Sleep 30
            If (!(Test-Path -Path $objectPath)){
                Write-Verbose "Object wasn't created properly, trying a second time"
                $tempObjectName = "sysvolReplTempObject" + (Get-Date -f yyyyMMddHHmmss) + ".txt"
                $objectPath = "\\$SourceSystem\SYSVOL\$domainname\Scripts\$tempObjectName"
                "...!!!...TEMP OBJECT TO TEST AD REPLICATION LATENCY/CONVERGENCE...!!!..." | Out-File -FilePath $($TempObjectLocation + "\" + $tempObjectName)
                Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17006 -EntryType Information -message "CREATE SYSVOL Test object attempt Number 2 - $tempObjectName  - has been created on $SourceSystem in site - $site" -category "17006"
                Start-Sleep 30
            }

            If (!(Test-Path -Path $objectPath)){
                Write-Verbose "Object wasn't created properly after 2 tries, exiting..."
                Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17000 -EntryType Error -message "FAILURE to write SYSVOL test object to PDCE - $SourceSystem  in site - $site" -category "17000"
                #Write-Verbose "Sending Slack Alert"
                #New-SlackPost "Alert - FAILURE to write SYSVOL test object to PDCE - $SourceSystem  in site - $site"
                Exit
            }
            
            $startDateTime = Get-Date
            $i = 0
        }
        else {
            Write-Verbose 'PDCE is offline.  You should really resolve that before continuing.'
            Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17000 -EntryType Error -message "FAILURE to connect to PDCE - $SourceSystem  in site - $site" -category "17000"
            #Write-Verbose "Sending Slack Alert"
            #New-SlackPost "Alert - FAILURE to connect to PDCE - $SourceSystem  in site - $site"
            Exit
        }
        
        While ($continue) {
            $i++
            Write-Verbose 'Sleeping for 1 minute.'
            Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17008 -EntryType Information -message "SLEEPING SYSVOL test for 1 minute" -category "17008"
            Start-Sleep 60
            $replicated = $true
            Write-Verbose "Cycle - $i"
            Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17001 -EntryType Information -message "CHECKING SYSVOL ADRepl Cycle $i" -category "17001"
        
            Foreach ($dc in $DCList) {
                $site = (Get-ADDomainController $dc).site
                if (Test-NetConnection $dc -Port 445) {
                    Write-Verbose "Online - $dc"
                    $objectPath = "\\$dc\SYSVOL\$domainname\Scripts\$tempObjectName"
                    $connectionResult = "SUCCESS"
                }
                else {
                    Write-Verbose "!!!!!OFFLINE - $dc !!!!!"
                    $connectionResult = "FAILURE"
                    Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17000 -EntryType Error -message "FAILURE to connect to DC - $dc in site - $site" -category "17000"
                }
                # If The Connection To The DC Is Successful
                If ($connectionResult -eq "SUCCESS") {
                    If (Test-Path -Path $objectPath) {
                        # If The Temp Object Already Exists
                        Write-Verbose "     - Object [$tempObjectName] Now Does Exist In The NetLogon Share"
                        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17003 -EntryType Information -message "SUCCESS SYSVOL Object Successfully replicated to  - $dc in site - $site" -category "17003"
                    }
                    Else {
                        # If The Temp Object Does Not Yet Exist
                        Write-Verbose "     - Object [$tempObjectName] Does NOT Exist Yet In The NetLogon Share"
                        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17002 -EntryType Information -message "PENDING SYSVOL Object replication pending for  - $dc in site - $site" -category "17002"
                        $replicated = $false
                    }
                }
        		
                # If The Connection To The DC Is Unsuccessful
                If ($connectionResult -eq "FAILURE") {
                    Write-Verbose "     - Unable To Connect To DC/GC And Check For The Temp Object..."
                    Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17000 -EntryType Error -message "FAILURE to connect to DC - $dc in site - $site" -category "17000"
                }
            }
            If ($replicated) {
                $continue = $false
            } 
        
            If ($i -gt $MaxCycles) {
                $continue = $false
                #gather event history to see which DC did, and which did not, get the replication
                $list = Get-EventLog application -After (Get-Date).AddHours(-2) | where {($_.InstanceID -Match "17002") -OR ($_.InstanceID -Match "17003") -OR ($_.InstanceID -Match "17006")} 
                $RelevantEvents = $list |Select InstanceID,Message |Out-String
                
                Write-Verbose "Cycle has run $i times, and replication hasn't finished.  Need to generate an alert."
                Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17004 -EntryType Warning -message "INCOMPLETE SYSVOL Test cycle has run $i times without the object succesfully replicating to all DCs" -category "17004"
                $Alert = "In $domainname - the SYSVOL test cycle has run $i times without the object succesfully replicating to all DCs.  
                Please see the following support article $SupportArticle to help investigate
                
                Recent history:
                $RelevantEvents
                "
                $CurrentFailure = $true
                Send-Mail $Alert
                #Write-Verbose "Sending Slack Alert"
                #New-SlackPost "Alert - Incomplete SYSVOL Replication Cycle in the domain: $domainname"
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
        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17005 -EntryType Information -message "END of SYSVOL Test cycle - $output" -category "17005"
        
        Write-Verbose "`n  Start Time......: $(Get-Date $startDateTime -format "yyyy-MM-dd HH:mm:ss")"
        Write-Verbose "  End Time........: $(Get-Date $endDateTime -format "yyyy-MM-dd HH:mm:ss")"
        Write-Verbose "  Duration........: $duration Seconds"
        
        # Delete The Temp Object On The RWDC
        Write-Verbose "  Deleting Temp Text File..."
        Remove-Item "$TempObjectLocation\$tempObjectName" -Force
        Write-Verbose "  Temp Text File [$tempObjectName] Has Been Deleted On The Source System"
        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17007 -EntryType Information -message "DELETED SYSVOL Test object - $tempObjectName  - has been deleted." -category "17007"

        If (!$CurrentFailure){
            Write-Verbose "No Issues found in this run"
            $InError = Get-EventLog application -After (Get-Date).AddHours(-2) | where {($_.InstanceID -Match "17000") -or ($_.InstanceID -Match "17004")} 
            If ($InError) {
                Write-Verbose "Previous Errors Seen"
                #Previous run had an alert
                #No errors foun during this test so send email that the previous error(s) have cleared
                Send-AlertCleared
                #Write-Verbose "Sending Slack Message - Alert Cleared"
                #New-SlackPost "The previous alert, for AD SYSVOL Replication, has cleared."
                #Write-Output $InError
            }#End if
        }#End if
    }#End End
}