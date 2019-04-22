#Check Replication for the default partition in the domain  
Get-ADReplicationPartnerMetadata -Target "$env:userdnsdomain" -Scope Domain | Select-Object Server, Partner | export-csv c:\temp\ADRepl.csv -NoTypeInformation

Import-Module PSGraph
$servers = Import-Csv C:\Temp\ADRepl.csv

graph @{rankdir='LR'} {
$servers | ForEach-Object {
    $Server = ($_.Server -split'\.')[0]
    $_.Partner = $_.Partner.replace("CN=","")
    $Partner = ($_.Partner -split',')[1]
    node $Server.ToLower() @{shape='box'}
    Edge $Server.ToLower() $Partner.ToLower()
}
 } | Export-PSGraph -ShowGraph  -LayoutEngine Hierarchical
