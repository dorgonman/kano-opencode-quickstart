param (
    [string]$PathToAdd
)

if (-not $PathToAdd) {
    Write-Error "Path argument is required."
    exit 1
}

# Normalize path separators
$PathToAdd = $PathToAdd -replace "/", "\\"

try {
    $UserPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
    
    # Check if path is already present (case-insensitive simple check)
    if (";$UserPath;" -like "*;$PathToAdd;*") {
        # Already exists
        exit 0
    }

    Write-Host ""
    Write-Host "----------------------------------------------------------------"
    Write-Host "OpenCode Setup: Environment Variable Check"
    Write-Host "----------------------------------------------------------------"
    Write-Host "The following path is NOT in your permanent User PATH:"
    Write-Host "  $PathToAdd"
    Write-Host ""
    Write-Host "Adding this allows you to run 'opencode' and 'bun' from any terminal."
    
    $confirmation = Read-Host "Do you want to add it now? (Y/n)"
    if ($confirmation -eq "" -or $confirmation -match "^[Yy]") {
        $NewPath = $UserPath
        if (-not $NewPath.EndsWith(";")) {
            $NewPath += ";"
        }
        $NewPath += $PathToAdd
        
        [System.Environment]::SetEnvironmentVariable("Path", $NewPath, [System.EnvironmentVariableTarget]::User)
        
        Write-Host "Success: Path updated."
        Write-Host "  NOTE: You must restart your terminal/shell for this to take effect."
    }
    else {
        Write-Host "Skipped path update."
    }
    Write-Host "----------------------------------------------------------------"
    Write-Host ""
}
catch {
    $errorMessage = $_.Exception.Message
    Write-Error "Failed to update PATH: $errorMessage"
    exit 1
}
