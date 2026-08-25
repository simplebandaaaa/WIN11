$ErrorActionPreference = "Stop"

Write-Host "=============================================="
Write-Host " Configuring Windows RDP"
Write-Host "=============================================="

# ------------------------------------------------------------
# Validate password
# ------------------------------------------------------------

if ([string]::IsNullOrWhiteSpace($env:RDP_PASSWORD)) {
    throw "RDP_PASSWORD GitHub Secret is missing."
}

if ($env:RDP_PASSWORD.Length -lt 8) {
    throw "RDP_PASSWORD must be at least 8 characters."
}

# ------------------------------------------------------------
# Current GitHub runner account
# ------------------------------------------------------------

$username = $env:USERNAME

Write-Host "RDP user: $username"

# ------------------------------------------------------------
# Set password
# ------------------------------------------------------------

$password = ConvertTo-SecureString `
    $env:RDP_PASSWORD `
    -AsPlainText `
    -Force

Set-LocalUser `
    -Name $username `
    -Password $password

# ------------------------------------------------------------
# Enable Remote Desktop
# ------------------------------------------------------------

Write-Host "Enabling Remote Desktop..."

Set-ItemProperty `
    -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" `
    -Name "fDenyTSConnections" `
    -Value 0

# ------------------------------------------------------------
# Enable RDP firewall rules
# ------------------------------------------------------------

Write-Host "Enabling RDP firewall rules..."

Enable-NetFirewallRule `
    -DisplayGroup "Remote Desktop" `
    -ErrorAction SilentlyContinue

# ------------------------------------------------------------
# Configure Remote Desktop service
# ------------------------------------------------------------

Write-Host "Starting Remote Desktop service..."

Set-Service `
    -Name "TermService" `
    -StartupType Automatic

Start-Service `
    -Name "TermService" `
    -ErrorAction SilentlyContinue

# ------------------------------------------------------------
# Add user to Remote Desktop Users
# ------------------------------------------------------------

Write-Host "Configuring Remote Desktop Users group..."

try {
    Add-LocalGroupMember `
        -Group "Remote Desktop Users" `
        -Member $username `
        -ErrorAction SilentlyContinue
}
catch {
    Write-Host "User already belongs to Remote Desktop Users."
}

# ------------------------------------------------------------
# Verify
# ------------------------------------------------------------

Write-Host ""
Write-Host "=============================================="
Write-Host " RDP CONFIGURATION COMPLETE"
Write-Host "=============================================="

Write-Host ""
Write-Host "User:"
Write-Host $username

Write-Host ""
Write-Host "RDP service:"
Get-Service TermService |
    Select-Object Status, Name, StartType

Write-Host ""
Write-Host "RDP enabled:"
(Get-ItemProperty `
    "HKLM:\System\CurrentControlSet\Control\Terminal Server").fDenyTSConnections

Write-Host ""
Write-Host "RDP port:"
Write-Host "3389"
