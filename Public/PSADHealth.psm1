$Public = Get-ChildItem -Path $PSScriptRoot\Public\*.ps1

$Public | ForEach-Object {
    . $_.FullName
}


$configFile = Get-Content $PSScriptRoot\Private\config.json

If($configFile -contains "Default")
{
    Write-Warning -Message "Module loaded with default configuration."
    Write-Warning -Message "Please run Set-PSConfig to configure module for your environment"
}

