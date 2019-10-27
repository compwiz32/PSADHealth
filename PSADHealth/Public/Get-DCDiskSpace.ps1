Function Get-DCDiskspace {
      [cmdletBinding()]
      Param(
            [Parameter(Mandatory,Position=0)]
            [String]
            $DriveLetter
      )
      
      begin {
            Import-Module ActiveDirectory
            #Creates a global $configuration variable
            $null = Get-ADConfig
      }

      process {
            $DClist = (get-adgroupmember "Domain Controllers").name
            $FreeDiskThreshold = $Configuration.FreeDiskThreshold

            ForEach ($server in $DClist){

                  $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" -ComputerName $server | Where-Object { $_.DeviceId -eq $DriveLetter} 
                  $Size = (($disk | Measure-Object -Property Size -Sum).sum/1gb)
                  $FreeSpace = (($disk | Measure-Object -Property FreeSpace -Sum).sum/1gb)
                  $freepercent = [math]::round(($FreeSpace / $size) * 100,0)
                  $Diskinfo = [PSCustomObject]@{
                        Drive = $disk.Name
                        "Total Disk Size (GB)" = [math]::round($size,2)
                        "Free Disk Size (GB)" = [math]::round($FreeSpace,2)
                        "Percent Free (%)" = $freepercent
                  } #End $DiskInfo Calculations
            
            If ($Diskinfo.'Percent Free (%)' -lt $FreeDiskThreshold){
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
                        To = $Configuration.MailTo
                        From = $Configuration.MailFrom
                        SmtpServer = $Configuration.SmtpServer
                        Subject = $Subject
                        Body = $EmailBody
                        BodyAsHtml = $true
                  }
                  Send-MailMessage @mailParams
            
            } #End If


            } # End ForEach

      }

      end {}

}