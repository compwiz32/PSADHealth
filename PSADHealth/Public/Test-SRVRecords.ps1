Function Test-SRVRecords {

    [cmdletBinding()]
    Param()

    begin {
        Import-Module ActiveDirectory
        #Creates a global $configuration variable
        $null = Get-ADConfig
    }

    process {
        $DomainFQDN = (Get-ADDomain).dnsroot
        $DCList = ((Get-ADGroupMember "Domain Controllers").name).tolower()
        $DCCount = $DCList.Length
        $PDCEmulator = ((Get-ADDomainController -Discover -Service PrimaryDC).name).tolower()

        $MSDCSZoneName = "_msdcs." + $DomainFQDN

        $DC_SRV_Record = '_ldap._tcp.dc'
        $GC_SRV_Record = '_ldap._tcp.gc'
        $KDC_SRV_Record = '_kerberos._tcp.dc'
        $PDC_SRV_Record = '_ldap._tcp.pdc'

        $DC_SRV_RecordCount = (@(Get-DnsServerResourceRecord -ZoneName $MSDCSZoneName -Name $DC_SRV_Record -RRType srv -ComputerName $PDCEmulator |
                ForEach-Object { $_.RecordData.DomainName.toLower() } | Sort-Object | Get-Unique).count)
        $GC_SRV_RecordCount = (@(Get-DnsServerResourceRecord -ZoneName $MSDCSZoneName -Name $GC_SRV_Record -RRType srv -ComputerName $PDCEmulator |
                ForEach-Object { $_.RecordData.DomainName.toLower() } | Sort-Object | Get-Unique).count)
        $KDC_SRV_RecordCount = (@(Get-DnsServerResourceRecord -ZoneName $MSDCSZoneName -Name $KDC_SRV_Record -RRType srv -ComputerName $PDCEmulator |
                ForEach-Object { $_.RecordData.DomainName.toLower() } | Sort-Object | Get-Unique).count)
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
            If ($record.values -lt $DCCount) {
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

        If ($PDC_SRV_RecordCount -lt 1) {
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
