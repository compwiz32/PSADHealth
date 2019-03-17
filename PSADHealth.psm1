$Public = Get-ChildItem -Path $PSScriptRoot\Public\*.ps1
$Private = Get-ChildItem -Path $PSScriptRoot\Private\*.ps1

Foreach($Script in @($Public + $Private)){

    . $Script.FullName

}