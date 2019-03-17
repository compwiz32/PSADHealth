Function Test-SRVRecords {

    [cmdletBinding()]
    Param()

    begin {
        Import-Module ActiveDirectory
        #Creates a global $configuration variable
        $null = Get-ADConfig
    }

    process {
        $DomainFQDN = (get-addomain).dnsroot
        $DCList = (get-adgroupmember "Domain Controllers").name
        $DCCount = (get-adgroupmember "Domain Controllers").count
        $PDCEmulator = (get-addomaincontroller -Discover -Service PrimaryDC).name
        $MSDCSZoneName = "_msdcs." + $DomainFQDN
        
        # $MSDCSZoneName = '_msdcs.bigfirm.biz'
        
        $DC_SRV_Record = '_ldap._tcp.dc'
        $GC_SRV_Record = '_ldap._tcp.gc'
        $KDC_SRV_Record = '_kerberos._tcp.dc'
        $PDC_SRV_Record = '_ldap._tcp.pdc'
        
        $Results = @{}      

        $Results.DC_SRV_RecordCount = ((Get-DnsServerResourceRecord -ZoneName $MSDCSZoneName -Name $DC_SRV_Record -RRType srv -ComputerName $PDCEmulator).count)
        $Results.GC_SRV_RecordCount = ((Get-DnsServerResourceRecord -ZoneName $MSDCSZoneName -Name $GC_SRV_Record -RRType srv -ComputerName $PDCEmulator).count)
        $Results.KDC_SRV_RecordCount = ((Get-DnsServerResourceRecord -ZoneName $MSDCSZoneName -Name $KDC_SRV_Record -RRType srv -ComputerName $PDCEmulator).count)

        $PDC_SRV_RecordCount = (@(Get-DnsServerResourceRecord -ZoneName $MSDCSZoneName -Name $PDC_SRV_Record -RRType srv -ComputerName $PDCEmulator).Count -ne 1)

        ForEach ($Record in $Results.key){
            If ($Record -ne $DCCount){
            
            $Subject = "There is an SRV record missing from DNS"
                $EmailBody = @"
        
        
        The <font color="Red"><b> $Record </b></font> in DNS does not match the number of Domain Controllers in Active Directory. Please check $MSDCSZoneName DNS Zone for missing SRV records.
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

            } #End if
        }#End Foreach


        If ($PDC_SRV_RecordCount -ne 1) { 
                
                $Subject = "The PDC SRV record is missing from DNS"
                $EmailBody = @"
        
        
        The <font color="Red"><b> PDC SRV record</b></font> is missing from the $MSDCSZoneName in DNS.
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

            } #END PDC If

    }

    end {}
}