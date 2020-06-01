Function Get-DCDiskspace {
      [cmdletBinding()]
      Param(
            [Parameter(Mandatory, Position = 0,HelpMessage="Please provide in 'C:' format")]
            [String]
            $DriveLetter
      )
      <#
    .SYNOPSIS
    Monitor AD Domain Controller Disk space on the specified drive
    
    .DESCRIPTION
    This function is used to Monitor AD Domain Controller Disk space and send alerts if below the specified threshold

    .PARAMETER DriveLetter
    Provide the drive letter to be tested/monitored in 'C:' format (without the quotes)

    .EXAMPLE
    Run as a scheduled task on a tool server to remotely monitor disk space on all DCs in a specified domain.  

    .EXAMPLE
        PS C:\> $trigger = New-JobTrigger -Once -At 6:00AM -RepetitionInterval (New-TimeSpan -Hours 1) -RepeatIndefinitely
        PS C:\> $cred = Get-Credential DOMAIN\ServiceAccount
        PS C:\> $opt = New-ScheduledJobOption -RunElevated -RequireNetwork
        PS C:\> Register-ScheduledJob -Name Get-DCDiskspace -Trigger $trigger -Credential $cred -ScriptBlock {(Import-Module -Name PSADHealth); Get-DCDiskspace} -MaxResultCount 5 -ScheduledJobOption $opt

        Creates a scheduled task to run Get-DCDiskspace on a hourly basis. NOTE: Service account needs to be a Domain Admin or equivalent (Tier0) and must have the RunAsBatch and RunAsService privilege
   
    .NOTES
    Authors: Mike Kanakos, Greg Onstot
    Version: 0.0.5
    Version Date: 10/30/2019

    Updated: 05/29/2020
      Silenced the import of ActiveDirectory module because we don't really want to see that
      Added "Silently loaded ActiveDirectory module" statement in its place
      Added some Verbose statements for when troubleshooting or testing
      Default free space in the config file is 70. If you don't have at least 70% free, this will alert
            I think expecting 70% free on all DCs is excessive personally
            I think the config file should be changed to 30% free as a default
            Also, there is not an option in Set-PSADHealthConfig for this value (Yet!)
      Instead of Making DriveLetter a Mandatory Parameter, shouldn't it just default to C:?
            When I went to use it the first time, I just provided 'C' instead of 'C:' so it failed to find my disk
            Either that or provide a help message for the proper format for ease of discovery
      #>

      begin {
        Import-Module ActiveDirectory -Verbose:$false
        Write-Verbose -Message "Silently loaded ActiveDirectory module"
            #Creates a global $configuration variable
            $null = Get-ADConfig
      }

      process {
            $DClist = (get-adgroupmember "Domain Controllers").name
            Write-Verbose -Message "DCList: $DCList"
            $FreeDiskThreshold = $Configuration.FreeDiskThreshold
            Write-Verbose -Message "Expected Minimum Free Disk Space: $FreeDiskThreshold"

            ForEach ($server in $DClist) {
                  Write-Verbose -Message "Processing $server"
                  $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" -ComputerName $server | Where-Object { $_.DeviceId -eq $DriveLetter } 
                  Write-Verbose -Message "Disk       : $($disk.Name)"
                  $Size = (($disk | Measure-Object -Property Size -Sum).sum / 1gb)
                  Write-Verbose -Message "DiskSize   : $Size"
                  $FreeSpace = (($disk | Measure-Object -Property FreeSpace -Sum).sum / 1gb)
                  Write-Verbose -Message "FreeSpace  : $FreeSpace"
                  $freepercent = [math]::round(($FreeSpace / $size) * 100, 0)
                  Write-Verbose -Message "FreePercent: $freepercent"
                  $Diskinfo = [PSCustomObject]@{
                        Drive                  = $disk.Name
                        "Total Disk Size (GB)" = [math]::round($size, 2)
                        "Free Disk Size (GB)"  = [math]::round($FreeSpace, 2)
                        "Percent Free (%)"     = $freepercent
                  } #End $DiskInfo Calculations
            
                  If ($Diskinfo.'Percent Free (%)' -lt $FreeDiskThreshold) {
                        $Subject = "Low Disk Space: Server $Server"
                        $EmailBody = @"
            
            
            Server named <font color="Red"><b> $Server </b></font> is running low on disk space on drive $DriveLetter !
            <br/>
            $($Diskinfo | ConvertTo-Html -Fragment)
            <br/>
            Time of Event: <font color="Red"><b>"""$((get-date))"""</b></font><br/>
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
                        Write-Verbose -Message "Sent email notification about low free disk space on $Server"
                  } #End If


            } # End ForEach

      }

      end {
            Write-Verbose -Message "Finished check Free Disk Space for all Domain Controllers"
      }

}