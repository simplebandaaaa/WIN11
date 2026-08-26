$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================================"
Write-Host " ANDROID 26 EMULATOR SETUP"
Write-Host "============================================================"

# =============================================================
# PATHS
# =============================================================

$sdk = "C:\Android\android-sdk"

$emulator = "$sdk\emulator\emulator.exe"

$sdkmanager = "$sdk\cmdline-tools\latest\bin\sdkmanager.bat"

$avdmanager = "$sdk\cmdline-tools\latest\bin\avdmanager.bat"

$adb = "$sdk\platform-tools\adb.exe"

$avdName = "Android26"

$package = "system-images;android-26;google_apis;x86"

$avdHome = "$env:USERPROFILE\.android"

$avdPath = "$avdHome\avd\$avdName.avd"

# =============================================================
# ENVIRONMENT
# =============================================================

$env:ANDROID_HOME = $sdk
$env:ANDROID_SDK_ROOT = $sdk

$env:PATH = `
"$sdk\platform-tools;$sdk\emulator;$sdk\cmdline-tools\latest\bin;$env:PATH"

New-Item `
    -ItemType Directory `
    -Path $avdHome `
    -Force `
    | Out-Null

# =============================================================
# CHECK TOOLS
# =============================================================

Write-Host ""
Write-Host "Checking Android tools..."

if (-not (Test-Path $emulator)) {
    throw "Android emulator not found: $emulator"
}

if (-not (Test-Path $sdkmanager)) {
    throw "sdkmanager not found: $sdkmanager"
}

if (-not (Test-Path $avdmanager)) {
    throw "avdmanager not found: $avdmanager"
}

if (-not (Test-Path $adb)) {
    throw "ADB not found: $adb"
}

Write-Host "Android tools OK."

# =============================================================
# INSTALL SYSTEM IMAGE
# =============================================================

Write-Host ""
Write-Host "Checking Android 26 system image..."

& $sdkmanager `
    "--list" `
    2>$null |
    Out-Null

Write-Host ""
Write-Host "Installing required Android 26 image..."

cmd.exe /c "`"$sdkmanager`" `"$package`""

if ($LASTEXITCODE -ne 0) {

    Write-Host ""
    Write-Host "sdkmanager returned exit code $LASTEXITCODE"

}

# =============================================================
# ACCEPT LICENSES
# =============================================================

Write-Host ""
Write-Host "Accepting Android SDK licenses..."

cmd.exe /c "echo y|`"$sdkmanager`" --licenses"

# =============================================================
# REMOVE OLD AVD
# =============================================================

Write-Host ""
Write-Host "Checking existing $avdName AVD..."

$existing = & $avdmanager list avd 2>$null

if ($existing -match "Name:\s*$avdName") {

    Write-Host "Existing $avdName found."

    Write-Host "Removing previous AVD..."

    cmd.exe /c "`"$avdmanager`" delete avd -n $avdName"

    Start-Sleep -Seconds 2

}
else {

    Write-Host "No previous $avdName AVD found."

}

# =============================================================
# CREATE AVD
# =============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " CREATING ANDROID26"
Write-Host "============================================================"

Write-Host ""
Write-Host "Package:"
Write-Host $package

Write-Host ""
Write-Host "Device:"
Write-Host "pixel"

# IMPORTANT:
# cmd.exe is used here so PowerShell UTF-8 BOM does not become
# "﻿no", which caused the previous avdmanager error.

$createCommand = `
"echo no | `"$avdmanager`" create avd -n $avdName -k `"$package`" -d pixel --force"

cmd.exe /c $createCommand

$createExit = $LASTEXITCODE

if ($createExit -ne 0) {

    Write-Host ""
    Write-Host "AVD creation returned exit code: $createExit"

    Write-Host ""
    Write-Host "Available AVDs:"

    & $avdmanager list avd

    throw "Failed to create Android26 AVD."

}

# =============================================================
# VERIFY AVD
# =============================================================

Write-Host ""
Write-Host "Verifying AVD..."

$avds = & $avdmanager list avd 2>$null

if ($avds -notmatch "Name:\s*$avdName") {

    Write-Host ""
    Write-Host "AVD manager output:"
    $avds

    throw "Android26 AVD was not found after creation."

}

Write-Host ""
Write-Host "Android26 AVD verified."

# =============================================================
# HARDWARE CONFIG
# =============================================================

Write-Host ""
Write-Host "Applying fast hardware configuration..."

$config = "$avdPath\config.ini"

if (-not (Test-Path $config)) {
    throw "AVD config not found: $config"
}

@"
hw.cpu.ncore=2
hw.ramSize=2048
vm.heapSize=256
hw.gpu.enabled=yes
hw.gpu.mode=swiftshader_indirect
hw.lcd.width=600
hw.lcd.height=960
hw.lcd.density=240
hw.keyboard=yes
hw.audioInput=no
hw.audioOutput=no
camera.back=none
camera.front=none
disk.dataPartition.size=4096M
fastboot.forceColdBoot=yes
"@ | Set-Content `
    -Path $config `
    -Encoding ASCII

# =============================================================
# ADB START
# =============================================================

Write-Host ""
Write-Host "Starting ADB..."

& $adb kill-server 2>$null

Start-Sleep -Seconds 1

& $adb start-server

Start-Sleep -Seconds 2

Write-Host "ADB server ready."

# =============================================================
# START EMULATOR
# =============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " STARTING ANDROID EMULATOR"
Write-Host "============================================================"

$arguments = @(
    "-avd", $avdName,
    "-no-snapshot",
    "-no-boot-anim",
    "-no-audio",
    "-camera-back", "none",
    "-camera-front", "none",
    "-gpu", "swiftshader_indirect",
    "-memory", "2048",
    "-cores", "2",
    "-no-metrics"
)

Write-Host ""
Write-Host "Emulator:"
Write-Host $emulator

Write-Host ""
Write-Host "Arguments:"
Write-Host ($arguments -join " ")

# Separate log files are intentional.
$emuLog = "$env:TEMP\android26-emulator.log"

if (Test-Path $emuLog) {
    Remove-Item $emuLog -Force -ErrorAction SilentlyContinue
}

# Start emulator without Start-Process redirect conflict.
$emuProcess = Start-Process `
    -FilePath $emulator `
    -ArgumentList $arguments `
    -PassThru `
    -WindowStyle Normal

Write-Host ""
Write-Host "Emulator PID:"
Write-Host $emuProcess.Id

# =============================================================
# WAIT FOR ADB
# =============================================================

Write-Host ""
Write-Host "Waiting for emulator..."

$booted = $false

for ($i = 1; $i -le 180; $i++) {

    Start-Sleep -Seconds 2

    $devices = & $adb devices 2>$null

    $deviceLine = $devices |
        Select-String "emulator-\d+\s+device"

    if ($deviceLine) {

        Write-Host ""
        Write-Host "ADB emulator detected at attempt $i."

        $bootState = & $adb -s emulator-5554 shell getprop sys.boot_completed 2>$null

        if ($bootState -match "1") {

            Write-Host ""
            Write-Host "Android boot completed."

            $booted = $true

            break
        }
    }

    if (($i % 10) -eq 0) {

        Write-Host ""
        Write-Host "Waiting... $i/180"

        Write-Host "ADB devices:"

        & $adb devices

        Write-Host ""
        Write-Host "Emulator process:"

        Get-Process emulator `
            -ErrorAction SilentlyContinue |
            Select-Object Id,ProcessName,CPU |
            Format-Table -AutoSize
    }
}

# =============================================================
# FAILURE DIAGNOSTICS
# =============================================================

if (-not $booted) {

    Write-Host ""
    Write-Host "============================================================"
    Write-Host " EMULATOR FAILED TO BOOT"
    Write-Host "============================================================"

    Write-Host ""
    Write-Host "ADB devices:"
    & $adb devices

    Write-Host ""
    Write-Host "Emulator processes:"

    Get-Process emulator `
        -ErrorAction SilentlyContinue |
        Select-Object Id,ProcessName,CPU,WorkingSet64 |
        Format-Table -AutoSize

    Write-Host ""
    Write-Host "AVD:"
    & $avdmanager list avd

    Write-Host ""
    Write-Host "AVD config:"
    Get-Content $config -ErrorAction SilentlyContinue

    throw "Android Emulator did not boot within 360 seconds."

}

# =============================================================
# DISABLE ANDROID ANIMATIONS
# =============================================================

Write-Host ""
Write-Host "Optimizing Android animations..."

& $adb -s emulator-5554 shell settings put global window_animation_scale 0 2>$null
& $adb -s emulator-5554 shell settings put global transition_animation_scale 0 2>$null
& $adb -s emulator-5554 shell settings put global animator_duration_scale 0 2>$null

# =============================================================
# FINAL
# =============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " ANDROID26 READY"
Write-Host "============================================================"

Write-Host ""
Write-Host "Android:"
Write-Host "Android 8.0 / API 26"

Write-Host ""
Write-Host "AVD:"
Write-Host "Android26"

Write-Host ""
Write-Host "ABI:"
Write-Host "x86"

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
Write-Host "Resolution:"
Write-Host "600x960"

Write-Host ""
Write-Host "Fullscreen:"
Write-Host "OFF"

Write-Host ""
Write-Host "Boot:"
Write-Host "COMPLETED"

Write-Host ""
Write-Host "============================================================"
