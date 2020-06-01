Function Test-SRVRecords {
    <#
    .SYNOPSIS
        Compares DNS entries to the number of domain controllers and notifies of inconsistencies

    .DESCRIPTION
        Compares DNS entries to the number of domain controllers and notifies of inconsistencies
        Checks the various records in the _msdcs.domainname zone for consistency with the number of DCs in the environment

    .EXAMPLE
        PS C:\> Test-SRVRecords
        
        Runs tests silently and only notifies you of issues

    .EXAMPLE
        PS C:\> Test-SRVRecords -Verbose
        
        Runs tests with feedback of progress and only notifies you via email if there are issues

    .EXAMPLE
        PS C:\> $trigger = New-JobTrigger -Once -At 6:00AM -RepetitionInterval (New-TimeSpan -Hours 1) -RepeatIndefinitely
        PS C:\> $cred = Get-Credential DOMAIN\ServiceAccount
        PS C:\> $opt = New-ScheduledJobOption -RunElevated -RequireNetwork
        PS C:\> Register-ScheduledJob -Name Test-SRVRecords -Trigger $trigger -Credential $cred -ScriptBlock {(Import-Module -Name PSADHealth); Test-SRVRecords} -MaxResultCount 5 -ScheduledJobOption $opt

        Creates a scheduled task to run Test-SRVRecords on an hourly basis. NOTE: Service account needs to be a Domain Admin or equivalent (Tier0) and must have the RunAsBatch and RunAsService privilege

        .NOTES
        Changes by Charles Palmer 5/28/2020
        Verbosity Updates:
            Silenced the import of ActiveDirectory module because we don't really want to see that
            Added "Silently loaded ActiveDirectory module" statement in its place
            Added Verbose statement for each populated variable
            Added Verbose statement for object counts
        Added Comment based Help section (and these notes)
        Commentary:
            The version from the PSGallery doesn't contain the foreach/tolower code
                I had the extra records as called out in Issue #96. I had added the verbose statements to help me figure out what was wrong
            The assumption is missing records when sending the email. 
                Sometimes it has to do with extra records (retired DCs not cleaned up properly, duplicate entries based on case, etc.)
    #>
    [cmdletBinding()]
    Param()

    begin {
        Import-Module ActiveDirectory -Verbose:$false
        Write-Verbose -Message "Silently loaded ActiveDirectory module"
        #Creates a global $configuration variable
        $null = Get-ADConfig
    }

    process {
        $DomainFQDN = (Get-ADDomain).dnsroot
        Write-Verbose -Message "DomainFQDN: $DomainFQDN"
        $DCList = ((Get-ADGroupMember "Domain Controllers").name).tolower()
        Write-Verbose -Message "DCList: $DCList"
        $DCCount = $DCList.Length
        Write-Verbose -Message "DCCount: $DCCount"
        $PDCEmulator = ((Get-ADDomainController -Discover -Service PrimaryDC).name).tolower()
        Write-Verbose -Message "PDCEmulator: $PDCEmulator"

        $MSDCSZoneName = "_msdcs." + $DomainFQDN
        Write-Verbose -Message "MSDCSZoneName: $MSDCSZoneName"

        $DC_SRV_Record = '_ldap._tcp.dc'
        $GC_SRV_Record = '_ldap._tcp.gc'
        $KDC_SRV_Record = '_kerberos._tcp.dc'
        $PDC_SRV_Record = '_ldap._tcp.pdc'

        $DC_SRV_RecordCount = (@(Get-DnsServerResourceRecord -ZoneName $MSDCSZoneName -Name $DC_SRV_Record -RRType srv -ComputerName $PDCEmulator |
                ForEach-Object { $_.RecordData.DomainName.toLower() } | Sort-Object | Get-Unique).count)
        Write-Verbose -Message "DC_SRV_RecordCount: $DC_SRV_RecordCount"
        $GC_SRV_RecordCount = (@(Get-DnsServerResourceRecord -ZoneName $MSDCSZoneName -Name $GC_SRV_Record -RRType srv -ComputerName $PDCEmulator |
                ForEach-Object { $_.RecordData.DomainName.toLower() } | Sort-Object | Get-Unique).count)
        Write-Verbose -Message "GC_SRV_RecordCount: $GC_SRV_RecordCount"
        $KDC_SRV_RecordCount = (@(Get-DnsServerResourceRecord -ZoneName $MSDCSZoneName -Name $KDC_SRV_Record -RRType srv -ComputerName $PDCEmulator |
                ForEach-Object { $_.RecordData.DomainName.toLower() } | Sort-Object | Get-Unique).count)
        Write-Verbose -Message "KDC_SRV_RecordCount: $KDC_SRV_RecordCount"
        $PDC_SRV_RecordCount = (@(Get-DnsServerResourceRecord -ZoneName $MSDCSZoneName -Name $PDC_SRV_Record -RRType srv -ComputerName $PDCEmulator).Count)
        Write-Verbose -Message "PDC_SRV_RecordCount: $PDC_SRV_RecordCount"

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
                Write-Verbose -Message "Sent email notification for failed SRV record in $($Record.keys) zone"
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
            Write-Verbose -Message "Sent email notification for failed PDC record in $MSDCSZoneName zone"
        } #END PDC If
    }
    end {
        Write-Verbose -Message "Finished testing DNS SRV Records for all DCs"
    }
}
