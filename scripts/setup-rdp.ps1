$ErrorActionPreference = "Stop"

Write-Host "=============================================="
Write-Host " Windows RDP Setup"
Write-Host "=============================================="

# ============================================================
# REQUIRE PASSWORD
# ============================================================

if ([string]::IsNullOrWhiteSpace($env:RDP_PASSWORD)) {
    throw "RDP_PASSWORD GitHub Secret is missing."
}

# ============================================================
# CREATE / UPDATE RDP USER
# ============================================================

$username = "rdpuser"
$password = ConvertTo-SecureString `
    $env:RDP_PASSWORD `
    -AsPlainText `
    -Force

Write-Host ""
Write-Host "Creating RDP user..."

$existingUser = Get-LocalUser `
    -Name $username `
    -ErrorAction SilentlyContinue

if ($existingUser) {

    Write-Host "Existing RDP user found."
    Write-Host "Updating password..."

    Set-LocalUser `
        -Name $username `
        -Password $password

}
else {

    New-LocalUser `
        -Name $username `
        -Password $password `
        -AccountNeverExpires `
        -PasswordNeverExpires `
        -UserMayNotChangePassword `
        -Description "GitHub Windows RDP user"

}

# ============================================================
# ADD TO REMOTE DESKTOP USERS
# ============================================================

Write-Host ""
Write-Host "Adding user to Remote Desktop Users..."

Add-LocalGroupMember `
    -Group "Remote Desktop Users" `
    -Member $username `
    -ErrorAction SilentlyContinue

# ============================================================
# ENABLE RDP
# ============================================================

Write-Host ""
Write-Host "Enabling Remote Desktop..."

Set-ItemProperty `
    -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" `
    -Name "fDenyTSConnections" `
    -Value 0

Set-ItemProperty `
    -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" `
    -Name "UserAuthentication" `
    -Value 1

# ============================================================
# FIREWALL
# ============================================================

Write-Host ""
Write-Host "Configuring RDP firewall..."

Enable-NetFirewallRule `
    -DisplayGroup "Remote Desktop" `
    -ErrorAction SilentlyContinue

# ============================================================
# NETWORK LEVEL AUTHENTICATION
# ============================================================

Set-ItemProperty `
    -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" `
    -Name "UserAuthentication" `
    -Type DWord `
    -Value 1

# ============================================================
# RDP SERVICE
# ============================================================

Write-Host ""
Write-Host "Starting Remote Desktop service..."

Set-Service `
    -Name "TermService" `
    -StartupType Automatic

Start-Service `
    -Name "TermService" `
    -ErrorAction SilentlyContinue

# ============================================================
# REDUCE RDP VISUAL TRAFFIC
# ============================================================

Write-Host ""
Write-Host "Applying low-data RDP settings..."

reg add `
    "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" `
    /v fDisableWallpaper `
    /t REG_DWORD `
    /d 1 `
    /f | Out-Null

reg add `
    "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" `
    /v fDisableFullWindowDrag `
    /t REG_DWORD `
    /d 1 `
    /f | Out-Null

reg add `
    "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" `
    /v fDisableMenuAnims `
    /t REG_DWORD `
    /d 1 `
    /f | Out-Null

reg add `
    "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" `
    /v fDisableThemes `
    /t REG_DWORD `
    /d 1 `
    /f | Out-Null

# ============================================================
# CHECK
# ============================================================

Write-Host ""
Write-Host "=============================================="
Write-Host " RDP READY"
Write-Host "=============================================="

Write-Host ""
Write-Host "Username:"
Write-Host $username

Write-Host ""
Write-Host "Port:"
Write-Host "3389"

Write-Host ""
Write-Host "RDP service:"
Write-Host "RUNNING"

Write-Host ""
Write-Host "=============================================="
