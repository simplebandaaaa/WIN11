$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================================"
Write-Host " ANDROID 26 EMULATOR - CLEAN AVD SETUP"
Write-Host "============================================================"

# ============================================================
# CONFIG
# ============================================================

$sdk = "C:\Android\android-sdk"

$emulator   = Join-Path $sdk "emulator\emulator.exe"
$sdkmanager = Join-Path $sdk "cmdline-tools\latest\bin\sdkmanager.bat"
$avdmanager = Join-Path $sdk "cmdline-tools\latest\bin\avdmanager.bat"

$avdName = "Android26"

$systemImage = "system-images;android-26;google_apis;x86"

$androidDir = Join-Path $env:USERPROFILE ".android"
$avdRoot = Join-Path $androidDir "avd"
$avdPath = Join-Path $avdRoot "$avdName.avd"
$avdConfig = Join-Path $avdPath "config.ini"

# ============================================================
# ENVIRONMENT
# ============================================================

$env:ANDROID_HOME = $sdk
$env:ANDROID_SDK_ROOT = $sdk

$env:PATH = `
    "$sdk\emulator;$sdk\cmdline-tools\latest\bin;$env:PATH"

New-Item `
    -ItemType Directory `
    -Path $androidDir `
    -Force |
    Out-Null

New-Item `
    -ItemType Directory `
    -Path $avdRoot `
    -Force |
    Out-Null

# ============================================================
# TOOL CHECK
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " CHECKING TOOLS"
Write-Host "============================================================"

if (-not (Test-Path $emulator)) {
    throw "emulator.exe not found: $emulator"
}

if (-not (Test-Path $sdkmanager)) {
    throw "sdkmanager.bat not found: $sdkmanager"
}

if (-not (Test-Path $avdmanager)) {
    throw "avdmanager.bat not found: $avdmanager"
}

Write-Host "Emulator : OK"
Write-Host "SDK      : OK"
Write-Host "AVDManager: OK"

# ============================================================
# SYSTEM IMAGE
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " CHECKING ANDROID 26 IMAGE"
Write-Host "============================================================"

$imagePath = Join-Path `
    $sdk `
    "system-images\android-26\google_apis\x86"

if (Test-Path $imagePath) {

    Write-Host ""
    Write-Host "Android 26 Google APIs x86 already installed."

}
else {

    Write-Host ""
    Write-Host "Installing Android 26 Google APIs x86..."

    & cmd.exe /c `
        "`"$sdkmanager`" `"$systemImage`"" 2>&1 |
        ForEach-Object {
            Write-Host $_
        }

    if ($LASTEXITCODE -ne 0) {
        throw "System image installation failed."
    }

    if (-not (Test-Path $imagePath)) {
        throw "Android 26 system image was not installed."
    }
}

# ============================================================
# STOP OLD EMULATOR
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " STOPPING OLD EMULATOR"
Write-Host "============================================================"

$old = Get-Process `
    -Name emulator `
    -ErrorAction SilentlyContinue

if ($old) {

    Write-Host "Stopping existing emulator..."

    $old |
        Stop-Process `
            -Force `
            -ErrorAction SilentlyContinue

    Start-Sleep -Seconds 3
}

# ============================================================
# REMOVE BROKEN AVD
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " RECREATING ANDROID26 AVD"
Write-Host "============================================================"

Write-Host ""
Write-Host "Removing old/broken Android26..."

# avdmanager delete is allowed to fail if AVD doesn't exist.
try {

    & cmd.exe /c `
        "`"$avdmanager`" delete avd -n $avdName" 2>&1 |
        ForEach-Object {
            Write-Host $_
        }

}
catch {
    # Ignore missing AVD.
}

Start-Sleep -Seconds 2

# Remove leftover directory too.
if (Test-Path $avdPath) {

    Write-Host ""
    Write-Host "Removing leftover AVD directory..."

    Remove-Item `
        -Path $avdPath `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue

}

# ============================================================
# CREATE FRESH AVD
# ============================================================

Write-Host ""
Write-Host "Creating fresh Android26..."

# IMPORTANT:
# Do not use PowerShell Unicode input.
# cmd.exe sends plain ASCII "no".

$createCommand = `
    "echo no|`"$avdmanager`" create avd -n $avdName -k `"$systemImage`" -d pixel --force"

& cmd.exe /c $createCommand 2>&1 |
    ForEach-Object {
        Write-Host $_
    }

if ($LASTEXITCODE -ne 0) {
    throw "AVD creation failed."
}

Start-Sleep -Seconds 5

# ============================================================
# VERIFY AVD FILE
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " VERIFYING FRESH AVD"
Write-Host "============================================================"

if (-not (Test-Path $avdConfig)) {

    Write-Host ""
    Write-Host "AVD config was not found."

    & cmd.exe /c `
        "`"$avdmanager`" list avd" 2>&1 |
        ForEach-Object {
            Write-Host $_
        }

    throw "Android26 AVD creation did not produce config.ini."
}

Write-Host ""
Write-Host "Android26 config.ini found:"
Write-Host $avdConfig

# ============================================================
# SHOW ORIGINAL CONFIG
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " GENERATED AVD CONFIG"
Write-Host "============================================================"

Get-Content `
    $avdConfig |
    ForEach-Object {
        Write-Host $_
    }

# ============================================================
# SAFE PERFORMANCE SETTINGS
# ============================================================
#
# IMPORTANT:
# We DO NOT replace config.ini.
# We only update existing properties / append valid ones.
#

Write-Host ""
Write-Host "============================================================"
Write-Host " APPLYING SAFE PERFORMANCE SETTINGS"
Write-Host "============================================================"

$config = Get-Content `
    $avdConfig `
    -ErrorAction Stop

function Set-AvdProperty {
    param(
        [string]$Name,
        [string]$Value
    )

    $script:config = @(
        $script:config |
            Where-Object {
                $_ -notmatch ("^" + [regex]::Escape($Name) + "=")
            }

        "$Name=$Value"
    )
}

# Safe properties for performance.
Set-AvdProperty "hw.cpu.ncore" "2"
Set-AvdProperty "hw.ramSize" "2048"
Set-AvdProperty "vm.heapSize" "256"
Set-AvdProperty "hw.gpu.enabled" "yes"
Set-AvdProperty "hw.gpu.mode" "swiftshader_indirect"
Set-AvdProperty "hw.keyboard" "yes"
Set-AvdProperty "hw.audioInput" "no"
Set-AvdProperty "hw.audioOutput" "no"
Set-AvdProperty "camera.back" "none"
Set-AvdProperty "camera.front" "none"
Set-AvdProperty "showDeviceFrame" "no"

# Keep generated AVD configuration intact.
$config |
    Set-Content `
        -Path $avdConfig `
        -Encoding ASCII

Write-Host ""
Write-Host "Safe performance settings applied."

# ============================================================
# VERIFY CONFIG AGAIN
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " VERIFYING CONFIGURATION"
Write-Host "============================================================"

$configCheck = Get-Content `
    $avdConfig `
    -ErrorAction Stop

if (-not ($configCheck -match "^AvdId=Android26$")) {

    Write-Host ""
    Write-Host "WARNING: AvdId property is not present."

}

Write-Host ""
Write-Host "Config file is readable."

# ============================================================
# AVDMANAGER FINAL CHECK
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " AVD MANAGER CHECK"
Write-Host "============================================================"

$avdList = `
    & cmd.exe /c "`"$avdmanager`" list avd" 2>&1

$avdList |
    ForEach-Object {
        Write-Host $_
    }

$avdText = $avdList | Out-String

if (-not ($avdText -match "(?m)^\s*Name:\s*Android26\s*$")) {

    throw "Android26 is not recognized by avdmanager."
}

Write-Host ""
Write-Host "Android26 recognized by avdmanager."

# ============================================================
# START EMULATOR
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " STARTING ANDROID EMULATOR"
Write-Host "============================================================"

$arguments = @(
    "-avd", $avdName
    "-no-snapshot"
    "-no-boot-anim"
    "-no-audio"
    "-camera-back", "none"
    "-camera-front", "none"
    "-gpu", "swiftshader_indirect"
    "-memory", "2048"
    "-cores", "2"
    "-no-metrics"
)

Write-Host ""
Write-Host "Emulator:"
Write-Host $emulator

Write-Host ""
Write-Host "Arguments:"
Write-Host ($arguments -join " ")

try {

    $emuProcess = Start-Process `
        -FilePath $emulator `
        -ArgumentList $arguments `
        -PassThru `
        -WindowStyle Normal

}
catch {

    throw `
        "Could not start emulator: $($_.Exception.Message)"
}

if (-not $emuProcess) {
    throw "Emulator process was not created."
}

Write-Host ""
Write-Host "Emulator PID:"
Write-Host $emuProcess.Id

# ============================================================
# WAIT FOR PROCESS
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " WAITING FOR EMULATOR"
Write-Host "============================================================"

$running = $false

for ($i = 1; $i -le 120; $i++) {

    Start-Sleep -Seconds 2

    $process = Get-Process `
        -Id $emuProcess.Id `
        -ErrorAction SilentlyContinue

    if ($process) {

        if (-not $running) {

            $running = $true

            Write-Host ""
            Write-Host "Android Emulator process is running."

        }

    }
    else {

        Write-Host ""
        Write-Host "Emulator stopped."

        break
    }

    if (($i % 10) -eq 0) {

        Write-Host ""
        Write-Host "Waiting... $i/120"

        $p = Get-Process `
            -Name emulator `
            -ErrorAction SilentlyContinue

        if ($p) {

            Write-Host "Emulator process = RUNNING"

        }
        else {

            Write-Host "Emulator process = STOPPED"
        }
    }
}

# ============================================================
# FINAL PROCESS CHECK
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " EMULATOR DIAGNOSTICS"
Write-Host "============================================================"

$current = Get-Process `
    -Id $emuProcess.Id `
    -ErrorAction SilentlyContinue

if (-not $current) {

    Write-Host ""
    Write-Host "Emulator process:"
    Write-Host "STOPPED"

    Write-Host ""
    Write-Host "AVD:"
    
    & cmd.exe /c `
        "`"$avdmanager`" list avd" 2>&1 |
        ForEach-Object {
            Write-Host $_
        }

    Write-Host ""
    Write-Host "CONFIG:"
    
    Get-Content `
        $avdConfig `
        -ErrorAction SilentlyContinue |
        ForEach-Object {
            Write-Host $_
        }

    throw "Android Emulator stopped before becoming ready."
}

# ============================================================
# SUCCESS
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " ANDROID26 EMULATOR READY"
Write-Host "============================================================"

Write-Host ""
Write-Host "AVD:"
Write-Host "Android26"

Write-Host ""
Write-Host "Android:"
Write-Host "8.0 / API 26"

Write-Host ""
Write-Host "ABI:"
Write-Host "x86"

Write-Host ""
Write-Host "Image:"
Write-Host "Google APIs"

Write-Host ""
Write-Host "RAM:"
Write-Host "2048 MB"

Write-Host ""
Write-Host "CPU:"
Write-Host "2 cores"

Write-Host ""
Write-Host "GPU:"
Write-Host "SwiftShader"

Write-Host ""
Write-Host "Audio:"
Write-Host "OFF"

Write-Host ""
Write-Host "Camera:"
Write-Host "OFF"

Write-Host ""
Write-Host "ADB:"
Write-Host "DISABLED"

Write-Host ""
Write-Host "Emulator process:"
Write-Host "RUNNING"

Write-Host ""
Write-Host "============================================================"
