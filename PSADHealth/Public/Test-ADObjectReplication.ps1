function Test-ADObjectReplication {
    [CmdletBinding()]
    Param()
    <#
    .SYNOPSIS
    Monitor AD Object Replication
    
    .DESCRIPTION
    Each run of the script creates a unique test object in the domain, and tracks it's replication to all other DCs in the domain.
    By default it will query the DCs for about 60 minutes.  If after 60 loops the object hasn't repliated the test will terminate and create an alert.

    .EXAMPLE
    Run as a scheduled task.  Use Event Log consolidation tools to pull and alert on issues found.

    .EXAMPLE
    Run in verbose mode if you want on-screen feedback for testing
   
    .NOTES
    Author Greg Onstot
    Version: 0.6.3
    Version Date: 04/18/2019

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
        Import-Module ActiveDirectory -Verbose:$false
        Write-Verbose -Message "Silently loaded ActiveDirectory module"
        $NBN = (Get-ADDomain).NetBIOSName
        Write-Verbose -Message "NetBIOSName: $NBN"
        $Domain = (Get-ADDomain).DNSRoot
        Write-Verbose -Message "Domain: $Domain"
        $domainname = (Get-ADDomain).dnsroot
        Write-Verbose -Message "FQDN: $domainname"
        $null = Get-ADConfig
        $SupportArticle = $Configuration.SupportArticle
        if (-not ([System.Diagnostics.EventLog]::SourceExists("PSMonitor"))) {
            Write-Verbose -Message "Adding Event Source."
            New-EventLog -LogName Application -Source "PSMonitor"
        }
        $continue = $true
        $CurrentFailure = $false
        $existingObj = $null
        $DCs = (Get-ADDomainController -Filter *).Name 
        Write-Verbose -Message "DCList: $DCs"
        $SourceSystem = (Get-ADDomain).pdcemulator
        Write-Verbose -Message "PDC: $SourceSystem"
        [int]$MaxCycles = $Configuration.MaxObjectReplCycles
        Write-Verbose -Message "Testing will commence for $MaxCycles cycles at maximum (1 minute sleep between cycles)"
    }

    Process {
        if (Test-NetConnection $SourceSystem -Port 445 -InformationLevel Quiet) {
            Write-Verbose -Message 'PDCE is online'
            $tempObjectPath = (Get-ADDomain).computersContainer
            $existingObj = Get-ADComputer -filter 'name -like "ADRT-*"' -prop * -SearchBase "$tempObjectPath" |Select-Object -ExpandProperty Name
            If ($existingObj){
                Write-Verbose -Message "Warning - Cleanup of a old object(s) may not have occured.  Object(s) starting with 'ADRT-' exists in $tempObjectPath : $existingObj  - Please review, and cleanup if required."
                Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17019 -EntryType Warning -message "WARNING - AD Object Replication Cleanup of old object(s) may not have occured.  Object(s) starting with 'ADRT-' exists in $tempObjectPath : $existingObj.  Please review, and cleanup if required." -category "17019"
                #Write-Verbose "Sending Slack Alert"
                #New-SlackPost "Alert - Cleanup of a old object(s) may not have occured.  Object(s) starting with 'ADRT-' exists in $tempObjectPath : $existingObj  - Please review, and cleanup if required."
            }

            $site = (Get-ADDomainController $SourceSystem).site
            $startDateTime = Get-Date
            [string]$tempObjectName = "ADRT-" + (Get-Date -f yyyyMMddHHmmss)
            
            New-ADComputer -Name "$tempObjectName" -samAccountName "$tempObjectName" -Path "$tempObjectPath" -Server $SourceSystem -Enabled $False
            
            Write-Verbose -Message "Object created for tracking - $tempObjectName in $site"
            Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17016 -EntryType Information -message "CREATED AD Object Replication Test object - $tempObjectName  - has been created on $SourceSystem in site - $site" -category "17016"
            $i = 0
        }
        else {
            Write-Verbose -Message 'PDCE is offline.  You should really resolve that before continuing.'
            Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17010 -EntryType Error -message "FAILURE AD Object Replication - Failed to connect to PDCE - $SourceSystem  in site - $site" -category "17010"
            $Alert = "In $domainname Failed to connect to PDCE - $dc in site - $site.  Test stopping!  See the following support article $SupportArticle"
            $CurrentFailure = $true
            Send-Mail $Alert
            #Write-Verbose "Sending Slack Alert"
            #New-SlackPost "Alert - PDCE is Offline in $domainname, AD Object Replication test has exited."
            Exit
        }

        While ($continue) {
            $i++
            Write-Verbose -Message 'Sleeping for 1 minute.'
            Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17018 -EntryType Information -message "SLEEPING AD Object Replication  for 1 minute" -category "17018"
            Start-Sleep 60
            $replicated = $true
            Write-Verbose -Message "Cycle - $i"
            Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17011 -EntryType Information -message "CHECKING AD Object Replication ADRepl Cycle $i" -category "17011"
        
            Foreach ($dc in $DCs) {
                $site = (Get-ADDomainController $dc).site
                if (Test-NetConnection $dc -Port 445 -InformationLevel Quiet) {
                    Write-Verbose -Message "Online - $dc"
                    $connectionResult = "SUCCESS"
                }
                else {
                    Write-Verbose -Message "!!!!!OFFLINE - $dc !!!!!"
                    $connectionResult = "FAILURE"
                    Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17010 -EntryType Error -message "FAILURE AD Object Replication failed to connect to DC - $dc in site - $site" -category "17010"
                    
                    $CurrentFailure = $true
                    if ($i -eq 10){
                        $Alert = "In $domainname Failed to connect to DC - $dc in site - $site.  See the following support article $SupportArticle"
                        #If we get a failure on the 10th run, send an email for additional visibility, but not spam on every pass if a server or site is offline.
                        Send-Mail $Alert
                        #Write-Verbose "Sending Slack Alert"
                        #New-SlackPost "Alert - In $domainname Failed to connect to DC - $dc in site - $site."
                    }
                    
                }

                # If The Connection To The DC Is Successful
                If ($connectionResult -eq "SUCCESS") {
                    Try {	
                        $Milliseconds = (Measure-Command {$Query = Get-ADComputer $tempObjectName -Server $dc | Select-Object Name}).TotalMilliseconds
                        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17013 -EntryType information -message "SUCCESS AD Object Replication Test object replicated to - $dc in site - $site - in $Milliseconds ms. " -category "17013"
                        write-Verbose -Message "SUCCESS! - Replicated -  $($query.Name) - $($dc) - $site - $Milliseconds"
                    }
                    Catch {
                        write-Verbose -Message "PENDING! - Test object $tempObjectName does not exist on $dc in $site."
                        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17012 -EntryType information -message "PENDING AD Object Replication Test object pending replication to - $dc in site - $site. " -category "17012"
                        $replicated = $false
                    }    
                }
        		
                # If The Connection To The DC Is Unsuccessful
                If ($connectionResult -eq "FAILURE") {
                    Write-Verbose -Message "     - Unable To Connect To DC/GC And Check For The Temp Object..."
                    Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17010 -EntryType Error -message "FAILURE AD Object Replication failed to connect to DC - $dc in site - $site" -category "17010"
                    $Alert = "In $domainname Failed to connect to DC - $dc in site - $site.   See the following support article $SupportArticle"
                    $CurrentFailure = $true
                    Send-Mail $Alert
                }
            }

            If ($replicated) {
                $continue = $false
            } 

            If ($i -gt $MaxCycles) {
                $continue = $false
                #gather event history to see which DC did, and which did not, get the replication
                $list = Get-EventLog application -After (Get-Date).AddHours(-2) | Where-Object {($_.InstanceID -Match "17012") -OR ($_.InstanceID -Match "17013") -OR ($_.InstanceID -Match "17016")} 
                $RelevantEvents = $list |Select-Object InstanceID,Message |Out-String
                Write-Verbose -Message "Cycle has run $i times, and replication hasn't finished.  Need to generate an alert."
                Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17014 -EntryType Warning -message "INCOMPLETE AD Object Replication Test cycle has run $i times without the object succesfully replicating to all DCs" -category "17014"
                
                $Alert = "In $domainname - the AD Object Replication Test cycle has run $i times without the object succesfully replicating to all DCs.  
                Please see the following support article $SupportArticle to help investigate
                
                Recent history:
                $RelevantEvents
                "
                $CurrentFailure = $true
                Send-Mail $Alert
                #Write-Verbose "Sending Slack Alert"
                #$New-SlackPost "Alert - In $domainname - the AD Object Replication Test cycle has run $i times without the object succesfully replicating to all DCs."                        
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
        
        Write-Verbose -Message "`n  Start Time......: $(Get-Date $startDateTime -format "yyyy-MM-dd HH:mm:ss")"
        Write-Verbose -Message "  End Time........: $(Get-Date $endDateTime -format "yyyy-MM-dd HH:mm:ss")"
        Write-Verbose -Message "  Duration........: $duration Seconds"
        
        # Delete The Temp Object On The RWDC
        Write-Verbose -Message "  Deleting AD Object File..."
        Remove-ADComputer $tempObjectName -Confirm:$False
        Write-Verbose -Message "  AD Object [$tempObjectName] Has Been Deleted."
        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17017 -EntryType Information -message "DELETED AD Object Replication test object - $tempObjectName  - has been deleted." -category "17017"

        If (!$CurrentFailure){
            Write-Verbose -Message "No Issues found in this run"
            $InError = Get-EventLog application -After (Get-Date).AddHours(-2) | Where-Object {($_.InstanceID -Match "17010") -or ($_.InstanceID -Match "17014")} 
            If ($InError) {
                Write-Verbose -Message "Previous Errors Seen"
                #Previous run had an alert
                #No errors foun during this test so send email that the previous error(s) have cleared
                Send-AlertCleared
                #Write-Verbose "Sending Slack Message - Alert Cleared"
                #New-SlackPost "The previous alert, for AD Object Replication, has cleared."
                #Write-Output $InError
            }#End if
        }#End if

    }
}
