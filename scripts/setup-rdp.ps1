$ErrorActionPreference = "Stop"

$work = "C:\Android\android-emulator-container-scripts"
$repo = "https://github.com/google/android-emulator-container-scripts.git"

$gateway = Join-Path $work "gateway"
$venv = Join-Path $gateway "venv"

$gatewayPort = 8080
$grpcPort = 8556

Write-Host ""
Write-Host "============================================================"
Write-Host " ANDROID EMULATOR WEBRTC GATEWAY"
Write-Host "============================================================"

# ------------------------------------------------------------
# Requirements
# ------------------------------------------------------------

$python = Get-Command python -ErrorAction SilentlyContinue

if (-not $python) {
    throw "Python is required. Install Python 3.10+ on the runner."
}

$git = Get-Command git -ErrorAction SilentlyContinue

if (-not $git) {
    throw "Git is required on the runner."
}

$pythonVersion = & python --version 2>&1

Write-Host ""
Write-Host "Python:"
Write-Host $pythonVersion

# ------------------------------------------------------------
# Clone/update official Google repository
# ------------------------------------------------------------

if (-not (Test-Path $work)) {

    Write-Host ""
    Write-Host "Cloning official Google WebRTC gateway..."

    & git clone --depth 1 $repo $work

    if ($LASTEXITCODE -ne 0) {
        throw "Git clone failed."
    }

}
else {

    Write-Host ""
    Write-Host "Google gateway repository already exists."

    Push-Location $work

    try {
        & git pull --ff-only
    }
    finally {
        Pop-Location
    }
}

if (-not (Test-Path $gateway)) {
    throw "Gateway directory not found: $gateway"
}

# ------------------------------------------------------------
# IMPORTANT WINDOWS CHECK
# ------------------------------------------------------------

Write-Host ""
Write-Host "Checking gateway platform..."

if ($env:OS -eq "Windows_NT") {

    Write-Host ""
    Write-Host "============================================================"
    Write-Host " WINDOWS RUNNER DETECTED"
    Write-Host "============================================================"

    Write-Host ""
    Write-Host "The official Google gateway is currently documented"
    Write-Host "for Linux environments."
    Write-Host ""
    Write-Host "A Windows-native gateway launch is therefore NOT"
    Write-Host "attempted here."
    Write-Host ""

    throw @"
The Android Emulator WebRTC gateway is Linux-oriented in the
official Google implementation.

Your Windows emulator can expose gRPC, but this PowerShell
script cannot safely pretend that the Python gateway is a
supported native Windows service.

Run the gateway inside WSL2/Linux, while keeping your existing
RDP/Tailscale Windows setup.
"@
}

# ------------------------------------------------------------
# Linux path
# ------------------------------------------------------------

Write-Host ""
Write-Host "Creating Python virtual environment..."

if (-not (Test-Path $venv)) {
    & python -m venv $venv

    if ($LASTEXITCODE -ne 0) {
        throw "Python virtual environment creation failed."
    }
}

$pythonVenv = Join-Path $venv "bin\python"

if (-not (Test-Path $pythonVenv)) {
    $pythonVenv = Join-Path $venv "Scripts\python.exe"
}

if (-not (Test-Path $pythonVenv)) {
    throw "Virtual environment Python executable not found."
}

Write-Host ""
Write-Host "Installing gateway..."

Push-Location $gateway

try {

    & $pythonVenv -m pip install --upgrade pip

    if ($LASTEXITCODE -ne 0) {
        throw "pip upgrade failed."
    }

    & $pythonVenv -m pip install -e .

    if ($LASTEXITCODE -ne 0) {
        throw "Gateway installation failed."
    }

}
finally {
    Pop-Location
}

# ------------------------------------------------------------
# Locate emulator discovery file
# ------------------------------------------------------------

Write-Host ""
Write-Host "Searching for emulator discovery file..."

$home = $env:HOME

if (-not $home) {
    $home = $env:USERPROFILE
}

$runningDir = Join-Path $home ".android\avd\running"

$discovery = Get-ChildItem `
    -Path $runningDir `
    -Filter "pid_*.ini" `
    -File `
    -ErrorAction SilentlyContinue |
    Select-Object -First 1

if (-not $discovery) {

    Write-Host ""
    Write-Host "No running emulator discovery file found."

    Write-Host ""
    Write-Host "Expected directory:"
    Write-Host $runningDir

    throw "Start Android26 before starting the WebRTC gateway."
}

$discoveryPath = $discovery.FullName

Write-Host ""
Write-Host "Discovery:"
Write-Host $discoveryPath

# ------------------------------------------------------------
# Gateway
# ------------------------------------------------------------

$gatewayExe = Get-Command `
    videobridge-gateway `
    -ErrorAction SilentlyContinue

if (-not $gatewayExe) {

    $gatewayExePath = Join-Path `
        (Split-Path $pythonVenv) `
        "videobridge-gateway.exe"

    if (Test-Path $gatewayExePath) {
        $gatewayExe = $gatewayExePath
    }
    else {
        throw "videobridge-gateway executable was not installed."
    }
}

Write-Host ""
Write-Host "============================================================"
Write-Host " STARTING WEBRTC GATEWAY"
Write-Host "============================================================"

Write-Host ""
Write-Host "Gateway:"
Write-Host "127.0.0.1:$gatewayPort"

Write-Host ""
Write-Host "Emulator gRPC:"
Write-Host "127.0.0.1:$grpcPort"

Write-Host ""
Write-Host "Browser frontend:"
Write-Host "https://pokowaka.github.io/android-emulator-webrtc/?url=localhost:$gatewayPort"

& $gatewayExe `
    "--port=$gatewayPort" `
    "--discovery_file=$discoveryPath" `
    "--webrtc_log_level=warning"
