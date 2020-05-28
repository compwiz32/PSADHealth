$Private = @(Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -Exclude *.tests.ps1 -ErrorAction SilentlyContinue)
$Public = @(Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -Exclude *.tests.ps1 -ErrorAction SilentlyContinue)

ForEach ($import in @($Public + $Private)) {
    Try {
        . $import.FullName
    }
    Catch {
        Write-Error -Message "Failed to import function $($import.FullName): $_"	
    }
}
foreach ($function in $Public) {
    $func = $function.BaseName -replace 'Function-', ''
    Export-ModuleMember -Function $func
}
