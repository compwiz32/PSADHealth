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
        $DCList = ((get-adgroupmember "Domain Controllers").name).tolower()
        $DCCount = (get-adgroupmember "Domain Controllers").count
        $PDCEmulator = ((get-addomaincontroller -Discover -Service PrimaryDC).name).tolower()
        $MSDCSZoneName = "_msdcs." + $DomainFQDN
        
        $DC_SRV_Record = '_ldap._tcp.dc'
        $GC_SRV_Record = '_ldap._tcp.gc'
        $KDC_SRV_Record = '_kerberos._tcp.dc'
        $PDC_SRV_Record = '_ldap._tcp.pdc'
        
        $DC_SRV_RecordCount = (@(Get-DnsServerResourceRecord -ZoneName $MSDCSZoneName -Name $DC_SRV_Record -RRType srv -ComputerName $PDCEmulator).count)
        $GC_SRV_RecordCount = (@(Get-DnsServerResourceRecord -ZoneName $MSDCSZoneName -Name $GC_SRV_Record -RRType srv -ComputerName $PDCEmulator).count)
        $KDC_SRV_RecordCount = (@(Get-DnsServerResourceRecord -ZoneName $MSDCSZoneName -Name $KDC_SRV_Record -RRType srv -ComputerName $PDCEmulator).count)
        $PDC_SRV_RecordCount = (@(Get-DnsServerResourceRecord -ZoneName $MSDCSZoneName -Name $PDC_SRV_Record -RRType srv -ComputerName $PDCEmulator).Count)

        $DCHash = @{ }
        $DCHash.add($dc_SRV_Record, $dc_SRV_RecordCount)
		
        $GCHash = @{ }
        $GCHash.add($gc_SRV_Record, $gc_SRV_RecordCount)
		
        $KDCHash = @{ }
        $KDCHash.add($kdc_SRV_Record, $kdc_SRV_RecordCount)

        $Records = @($DCHash, $GCHash, $KDCHash)
        ForEach ($Record in $Records) {
            # If ($Record -ne $DCCount){
            If ($record.values -ne $DCCount) {
                $Subject = "There is an SRV record missing from DNS"
                $EmailBody = @"
        
        
        The number of records in the <font color="Red"><b> $($Record.keys) </b></font> zone in DNS does not match the number of Domain Controllers in Active Directory. Please check  DNS for missing SRV records.
		
        Time of Event: <font color="Red"><b> $((get-date))</b></font><br/>
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
                To         = $Configuration.MailTo
                From       = $Configuration.MailFrom
                SmtpServer = $Configuration.SmtpServer
                Subject    = $Subject
                Body       = $EmailBody
                BodyAsHtml = $true
            }
            Send-MailMessage @mailParams
        } #END PDC If
    }
    end { }
}
