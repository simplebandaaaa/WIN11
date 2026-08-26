$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================================"
Write-Host " WINDOWS RDP + CHROME SETUP"
Write-Host "============================================================"

# =============================================================
# VARIABLES
# =============================================================

$password = $env:RDP_PASSWORD

if ([string]::IsNullOrWhiteSpace($password)) {
    throw "RDP_PASSWORD GitHub Secret is missing."
}

$user = "runneradmin"

# =============================================================
# FIND USER
# =============================================================

Write-Host ""
Write-Host "Checking Windows user..."

$localUser = Get-LocalUser `
    -Name $user `
    -ErrorAction SilentlyContinue

if (-not $localUser) {

    Write-Host "Creating $user..."

    $securePassword = ConvertTo-SecureString `
        $password `
        -AsPlainText `
        -Force

    New-LocalUser `
        -Name $user `
        -Password $securePassword `
        -AccountNeverExpires `
        -PasswordNeverExpires `
        -UserMayNotChangePassword `
        -Description "GitHub Android Emulator RDP user"

}
else {

    Write-Host "$user already exists."

    $securePassword = ConvertTo-SecureString `
        $password `
        -AsPlainText `
        -Force

    Set-LocalUser `
        -Name $user `
        -Password $securePassword
}

# =============================================================
# ADMINISTRATOR
# =============================================================

Write-Host ""
Write-Host "Adding user to Administrators..."

try {
    Add-LocalGroupMember `
        -Group "Administrators" `
        -Member $user `
        -ErrorAction SilentlyContinue
}
catch {
}

# =============================================================
# REMOTE DESKTOP USERS
# =============================================================

Write-Host ""
Write-Host "Adding user to Remote Desktop Users..."

try {
    Add-LocalGroupMember `
        -Group "Remote Desktop Users" `
        -Member $user `
        -ErrorAction SilentlyContinue
}
catch {
}

# =============================================================
# ENABLE RDP
# =============================================================

Write-Host ""
Write-Host "Enabling Windows Remote Desktop..."

Set-ItemProperty `
    -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" `
    -Name "fDenyTSConnections" `
    -Value 0

# =============================================================
# NETWORK LEVEL AUTHENTICATION
# =============================================================

Write-Host ""
Write-Host "Configuring RDP..."

Set-ItemProperty `
    -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" `
    -Name "UserAuthentication" `
    -Value 0

# =============================================================
# RDP SERVICE
# =============================================================

Write-Host ""
Write-Host "Starting Remote Desktop service..."

Set-Service `
    -Name TermService `
    -StartupType Automatic

Restart-Service `
    -Name TermService `
    -Force `
    -ErrorAction SilentlyContinue

# =============================================================
# FIREWALL
# =============================================================

Write-Host ""
Write-Host "Opening RDP firewall..."

Enable-NetFirewallRule `
    -DisplayGroup "Remote Desktop" `
    -ErrorAction SilentlyContinue

New-NetFirewallRule `
    -DisplayName "GitHub RDP 3389" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 3389 `
    -Action Allow `
    -Profile Any `
    -ErrorAction SilentlyContinue

# =============================================================
# FAST RDP SETTINGS
# =============================================================

Write-Host ""
Write-Host "Applying fast RDP settings..."

$rdpKey = `
"HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"

Set-ItemProperty `
    -Path $rdpKey `
    -Name "fDisableWallpaper" `
    -Value 1 `
    -ErrorAction SilentlyContinue

Set-ItemProperty `
    -Path $rdpKey `
    -Name "fDisableFullWindowDrag" `
    -Value 1 `
    -ErrorAction SilentlyContinue

Set-ItemProperty `
    -Path $rdpKey `
    -Name "fDisableMenuAnims" `
    -Value 1 `
    -ErrorAction SilentlyContinue

Set-ItemProperty `
    -Path $rdpKey `
    -Name "fDisableThemes" `
    -Value 1 `
    -ErrorAction SilentlyContinue

# =============================================================
# CHROME
# =============================================================

Write-Host ""
Write-Host "Checking Google Chrome..."

$chromePaths = @(
    "C:\Program Files\Google\Chrome\Application\chrome.exe",
    "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
)

$chrome = $null

foreach ($path in $chromePaths) {

    if (Test-Path $path) {
        $chrome = $path
        break
    }
}

if ($chrome) {

    Write-Host "Chrome found:"
    Write-Host $chrome

}
else {

    Write-Host "Chrome not found."
    Write-Host "Installing Chrome..."

    $installer = "$env:TEMP\ChromeSetup.exe"

    Invoke-WebRequest `
        -Uri "https://dl.google.com/chrome/install/latest/chrome_installer.exe" `
        -OutFile $installer

    Start-Process `
        -FilePath $installer `
        -ArgumentList "/silent","/install" `
        -Wait

    Remove-Item `
        $installer `
        -Force `
        -ErrorAction SilentlyContinue
}

# =============================================================
# CHROME SINGLE WINDOW
# =============================================================

Write-Host ""
Write-Host "Configuring Chrome..."

$chromePolicyPath = `
"HKLM:\SOFTWARE\Policies\Google\Chrome"

New-Item `
    -Path $chromePolicyPath `
    -Force `
    | Out-Null

# Don't restore previous tabs
New-ItemProperty `
    -Path $chromePolicyPath `
    -Name "RestoreOnStartup" `
    -PropertyType DWord `
    -Value 4 `
    -Force `
    | Out-Null

# =============================================================
# RDP PORT TEST
# =============================================================

Write-Host ""
Write-Host "Checking RDP port..."

Start-Sleep -Seconds 3

$rdpListener = Get-NetTCPConnection `
    -LocalPort 3389 `
    -State Listen `
    -ErrorAction SilentlyContinue

if ($rdpListener) {

    Write-Host "RDP 3389 = LISTENING"

}
else {

    Write-Host "WARNING: RDP 3389 is not listening yet."

}

# =============================================================
# FINAL
# =============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " WINDOWS RDP READY"
Write-Host "============================================================"

Write-Host ""
Write-Host "Username:"
Write-Host $user

Write-Host ""
Write-Host "RDP port:"
Write-Host "3389"

Write-Host ""
Write-Host "Chrome:"
Write-Host "READY"

Write-Host ""
Write-Host "Fullscreen:"
Write-Host "OFF"

Write-Host ""
Write-Host "============================================================"
