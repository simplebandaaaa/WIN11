$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=============================================="
Write-Host " Windows RDP + Browser Display Setup"
Write-Host "=============================================="

# ============================================================
# PASSWORD
# ============================================================

if ([string]::IsNullOrWhiteSpace($env:RDP_PASSWORD)) {
    throw "RDP_PASSWORD GitHub Secret is missing."
}

$RdpPassword = $env:RDP_PASSWORD

# ============================================================
# CURRENT USER
# ============================================================

$UserName = $env:USERNAME

Write-Host ""
Write-Host "Windows user:"
Write-Host $UserName

# ============================================================
# SET PASSWORD
# ============================================================

Write-Host ""
Write-Host "Setting Windows password..."

$securePassword = ConvertTo-SecureString `
    $RdpPassword `
    -AsPlainText `
    -Force

Set-LocalUser `
    -Name $UserName `
    -Password $securePassword

# ============================================================
# ENABLE RDP
# ============================================================

Write-Host ""
Write-Host "Enabling Windows RDP..."

Set-ItemProperty `
    -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" `
    -Name "fDenyTSConnections" `
    -Value 0

Set-ItemProperty `
    -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" `
    -Name "UserAuthentication" `
    -Value 0

# ============================================================
# FIREWALL
# ============================================================

Write-Host ""
Write-Host "Configuring RDP firewall..."

Enable-NetFirewallRule `
    -DisplayGroup "Remote Desktop" `
    -ErrorAction SilentlyContinue

# ============================================================
# RDP SERVICE
# ============================================================

Write-Host ""
Write-Host "Starting RDP service..."

Set-Service `
    -Name TermService `
    -StartupType Automatic

Start-Service `
    -Name TermService `
    -ErrorAction SilentlyContinue

# ============================================================
# INSTALL CHOCOLATEY IF NEEDED
# ============================================================

Write-Host ""
Write-Host "Checking Chocolatey..."

$choco = Get-Command choco -ErrorAction SilentlyContinue

if (-not $choco) {

    Write-Host "Installing Chocolatey..."

    Set-ExecutionPolicy `
        Bypass `
        -Scope Process `
        -Force

    [System.Net.ServicePointManager]::SecurityProtocol = `
        [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

    Invoke-Expression `
        ((New-Object System.Net.WebClient).DownloadString(
            "https://community.chocolatey.org/install.ps1"
        ))
}

# ============================================================
# INSTALL TIGHTVNC
# ============================================================

Write-Host ""
Write-Host "Installing VNC server..."

& choco install tightvnc `
    -y `
    --no-progress `
    --ignore-checksums

if ($LASTEXITCODE -ne 0) {
    Write-Host "Chocolatey VNC installation returned code $LASTEXITCODE."
}

# ============================================================
# FIND TVN SERVER
# ============================================================

$TightVnc = $null

$candidates = @(
    "C:\Program Files\TightVNC\tvnserver.exe",
    "C:\Program Files (x86)\TightVNC\tvnserver.exe"
)

foreach ($candidate in $candidates) {

    if (Test-Path $candidate) {
        $TightVnc = $candidate
        break
    }
}

if (-not $TightVnc) {

    $found = Get-ChildItem `
        -Path "C:\Program Files",
        "C:\Program Files (x86)" `
        -Filter "tvnserver.exe" `
        -Recurse `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($found) {
        $TightVnc = $found.FullName
    }
}

if (-not $TightVnc) {
    throw "TightVNC server was not found after installation."
}

Write-Host ""
Write-Host "TightVNC:"
Write-Host $TightVnc

# ============================================================
# VNC CONFIG DIRECTORY
# ============================================================

$VncDir = "C:\VNC"

New-Item `
    -ItemType Directory `
    -Path $VncDir `
    -Force | Out-Null

# ============================================================
# START VNC SERVER
# ============================================================

Write-Host ""
Write-Host "Starting VNC server..."

Get-Process `
    -Name tvnserver `
    -ErrorAction SilentlyContinue |
    Stop-Process `
        -Force `
        -ErrorAction SilentlyContinue

Start-Sleep -Seconds 2

$tvn = Start-Process `
    -FilePath $TightVnc `
    -ArgumentList @(
        "-run"
    ) `
    -PassThru `
    -WindowStyle Hidden

Start-Sleep -Seconds 5

if (-not $tvn) {
    throw "TightVNC failed to start."
}

Write-Host "TightVNC started."

# ============================================================
# VNC FIREWALL
# ============================================================

Write-Host ""
Write-Host "Opening VNC port..."

New-NetFirewallRule `
    -DisplayName "Android Emulator VNC" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 5901 `
    -Action Allow `
    -ErrorAction SilentlyContinue

# ============================================================
# DOWNLOAD NOVNC
# ============================================================

Write-Host ""
Write-Host "Installing noVNC..."

$NoVncDir = "C:\noVNC"

if (Test-Path $NoVncDir) {

    Remove-Item `
        -Path $NoVncDir `
        -Recurse `
        -Force
}

git clone `
    --depth 1 `
    "https://github.com/novnc/noVNC.git" `
    $NoVncDir

if (-not (Test-Path "$NoVncDir\vnc.html")) {
    throw "noVNC installation failed."
}

# ============================================================
# PYTHON
# ============================================================

$python = Get-Command python -ErrorAction SilentlyContinue

if (-not $python) {
    throw "Python is required for noVNC/websockify."
}

Write-Host ""
Write-Host "Python:"
Write-Host $python.Source

# ============================================================
# INSTALL WEBSOCKIFY
# ============================================================

Write-Host ""
Write-Host "Installing websockify..."

& python -m pip install `
    --disable-pip-version-check `
    --no-warn-script-location `
    websockify

if ($LASTEXITCODE -ne 0) {
    throw "websockify installation failed."
}

# ============================================================
# START NOVNC
# ============================================================

Write-Host ""
Write-Host "Starting noVNC..."

$WebLog = "C:\noVNC\websockify.log"

Remove-Item `
    $WebLog `
    -Force `
    -ErrorAction SilentlyContinue

$websockify = Join-Path `
    (Split-Path $python.Source) `
    "Scripts\websockify.exe"

if (-not (Test-Path $websockify)) {

    $websockify = Get-Command `
        websockify `
        -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty Source
}

if (-not $websockify) {
    throw "websockify.exe was not found."
}

# ============================================================
# WEB DISPLAY PORT
# ============================================================

$WebPort = 8080

# ============================================================
# START WEBSOCKIFY
# ============================================================

$webArgs = @(
    "--web=$NoVncDir",
    "0.0.0.0:$WebPort",
    "127.0.0.1:5901"
)

$webProcess = Start-Process `
    -FilePath $websockify `
    -ArgumentList $webArgs `
    -RedirectStandardOutput $WebLog `
    -RedirectStandardError "$WebLog.err" `
    -WindowStyle Hidden `
    -PassThru

if (-not $webProcess) {
    throw "Failed to start noVNC/websockify."
}

Start-Sleep -Seconds 5

# ============================================================
# FIREWALL 8080
# ============================================================

Write-Host ""
Write-Host "Opening browser port 8080..."

New-NetFirewallRule `
    -DisplayName "Android Emulator Browser" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 8080 `
    -Action Allow `
    -ErrorAction SilentlyContinue

# ============================================================
# VERIFY PORT
# ============================================================

Write-Host ""
Write-Host "Checking browser port..."

$listen = Get-NetTCPConnection `
    -LocalPort 8080 `
    -State Listen `
    -ErrorAction SilentlyContinue

if (-not $listen) {

    Write-Host ""
    Write-Host "websockify log:"

    if (Test-Path $WebLog) {
        Get-Content $WebLog -Tail 100
    }

    throw "Browser port 8080 is not listening."
}

# ============================================================
# RESULT
# ============================================================

Write-Host ""
Write-Host "=============================================="
Write-Host " RDP + BROWSER DISPLAY READY"
Write-Host "=============================================="

Write-Host ""
Write-Host "RDP:"
Write-Host "3389"

Write-Host ""
Write-Host "VNC:"
Write-Host "5901"

Write-Host ""
Write-Host "Browser:"
Write-Host "8080"

Write-Host ""
Write-Host "noVNC:"
Write-Host "RUNNING"

Write-Host ""
Write-Host "Fullscreen:"
Write-Host "OFF"

Write-Host ""
Write-Host "Setup complete."
