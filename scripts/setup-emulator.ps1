$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================================"
Write-Host " ANDROID 26 EMULATOR - FINAL FAST SETUP"
Write-Host "============================================================"

# ============================================================
# CONFIGURATION
# ============================================================

$sdk = "C:\Android\android-sdk"

$emulator = Join-Path $sdk "emulator\emulator.exe"
$sdkmanager = Join-Path $sdk "cmdline-tools\latest\bin\sdkmanager.bat"
$avdmanager = Join-Path $sdk "cmdline-tools\latest\bin\avdmanager.bat"
$adb = Join-Path $sdk "platform-tools\adb.exe"

$avdName = "Android26"

$systemImage = "system-images;android-26;google_apis;x86"

$androidHome = Join-Path $env:USERPROFILE ".android"
$avdRoot = Join-Path $androidHome "avd"
$avdPath = Join-Path $avdRoot "$avdName.avd"
$avdConfig = Join-Path $avdPath "config.ini"

$adbPort = 5037
$emulatorPort = 5554

# ============================================================
# ENVIRONMENT
# ============================================================

$env:ANDROID_HOME = $sdk
$env:ANDROID_SDK_ROOT = $sdk

$env:PATH = "$sdk\platform-tools;$sdk\emulator;$sdk\cmdline-tools\latest\bin;$env:PATH"

New-Item `
    -ItemType Directory `
    -Path $androidHome `
    -Force `
    | Out-Null

New-Item `
    -ItemType Directory `
    -Path $avdRoot `
    -Force `
    | Out-Null

Write-Host ""
Write-Host "SDK:"
Write-Host $sdk

Write-Host ""
Write-Host "AVD:"
Write-Host $avdName

Write-Host ""
Write-Host "System image:"
Write-Host $systemImage

# ============================================================
# TOOL CHECK
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " CHECKING ANDROID TOOLS"
Write-Host "============================================================"

if (-not (Test-Path $emulator)) {
    throw "Emulator executable not found: $emulator"
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

Write-Host "Emulator : OK"
Write-Host "SDKManager: OK"
Write-Host "AVDManager: OK"
Write-Host "ADB       : OK"

# ============================================================
# LICENSES
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " ANDROID SDK LICENSES"
Write-Host "============================================================"

try {

    cmd.exe /c "echo y|`"$sdkmanager`" --licenses" 2>&1 |
        ForEach-Object {
            Write-Host $_
        }

}
catch {

    Write-Host ""
    Write-Host "License command returned a non-fatal error."
}

# ============================================================
# SYSTEM IMAGE
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " ANDROID 26 SYSTEM IMAGE"
Write-Host "============================================================"

$systemImagePath = Join-Path `
    $sdk `
    "system-images\android-26\google_apis\x86"

if (Test-Path $systemImagePath) {

    Write-Host ""
    Write-Host "Android 26 x86 image already installed."

}
else {

    Write-Host ""
    Write-Host "Installing Android 26 Google APIs x86..."

    cmd.exe /c "`"$sdkmanager`" `"$systemImage`"" 2>&1 |
        ForEach-Object {
            Write-Host $_
        }

    if ($LASTEXITCODE -ne 0) {

        throw `
            "Android 26 system image installation failed. Exit code: $LASTEXITCODE"
    }

    if (-not (Test-Path $systemImagePath)) {

        throw `
            "System image installation finished but image directory was not found."
    }

    Write-Host ""
    Write-Host "System image installed."
}

# ============================================================
# EXISTING AVD
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " CHECKING ANDROID26 AVD"
Write-Host "============================================================"

if (Test-Path $avdConfig) {

    Write-Host ""
    Write-Host "Existing Android26 AVD found:"
    Write-Host $avdPath

}
else {

    Write-Host ""
    Write-Host "Android26 AVD does not exist."
    Write-Host "Creating new AVD..."
}

# ============================================================
# CREATE AVD
# ============================================================

if (-not (Test-Path $avdConfig)) {

    Write-Host ""
    Write-Host "============================================================"
    Write-Host " CREATING ANDROID26"
    Write-Host "============================================================"

    # --------------------------------------------------------
    # IMPORTANT:
    # We use cmd.exe + echo no.
    #
    # This avoids the UTF-8 BOM problem that previously caused:
    #
    # ﻿no is not a valid reply
    # --------------------------------------------------------

    $createCommand = `
        "echo no|`"$avdmanager`" create avd -n $avdName -k `"$systemImage`" -d pixel --force"

    Write-Host ""
    Write-Host "Running avdmanager..."

    cmd.exe /c $createCommand 2>&1 |
        ForEach-Object {
            Write-Host $_
        }

    $createExitCode = $LASTEXITCODE

    Write-Host ""
    Write-Host "AVD manager exit code:"
    Write-Host $createExitCode

    Start-Sleep -Seconds 3
}

# ============================================================
# ROBUST AVD VERIFICATION
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " VERIFYING ANDROID26 AVD"
Write-Host "============================================================"

Start-Sleep -Seconds 2

if (Test-Path $avdConfig) {

    Write-Host ""
    Write-Host "Android26 AVD verified successfully."
    Write-Host "AVD path:"
    Write-Host $avdPath

}
else {

    Write-Host ""
    Write-Host "AVD config not immediately visible."

    Write-Host ""
    Write-Host "Checking avdmanager..."

    $avdOutput = & $avdmanager list avd 2>&1

    $avdText = $avdOutput |
        Out-String

    Write-Host ""
    Write-Host $avdText

    Start-Sleep -Seconds 2

    if (Test-Path $avdConfig) {

        Write-Host ""
        Write-Host "Android26 AVD found after filesystem refresh."

    }
    elseif ($avdText -match "(?m)^\s*Name:\s*Android26\s*$") {

        Write-Host ""
        Write-Host "avdmanager confirms Android26 exists."

        if (-not (Test-Path $avdPath)) {

            throw `
                "avdmanager lists Android26 but AVD directory is unavailable: $avdPath"
        }

    }
    else {

        Write-Host ""
        Write-Host "Available AVDs:"
        Write-Host $avdText

        throw `
            "Android26 AVD could not be verified."
    }
}

# ============================================================
# CONFIG FILE CHECK
# ============================================================

if (-not (Test-Path $avdConfig)) {

    throw `
        "Android26 config.ini was not found: $avdConfig"
}

Write-Host ""
Write-Host "AVD config:"
Write-Host $avdConfig

# ============================================================
# FAST CONFIGURATION
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " APPLYING FAST EMULATOR SETTINGS"
Write-Host "============================================================"

$configLines = @(
    "hw.cpu.ncore=2"
    "hw.ramSize=2048"
    "vm.heapSize=256"
    "hw.gpu.enabled=yes"
    "hw.gpu.mode=swiftshader_indirect"
    "hw.lcd.width=600"
    "hw.lcd.height=960"
    "hw.lcd.density=240"
    "hw.keyboard=yes"
    "hw.audioInput=no"
    "hw.audioOutput=no"
    "camera.back=none"
    "camera.front=none"
    "disk.dataPartition.size=4096M"
    "fastboot.forceColdBoot=yes"
    "showDeviceFrame=no"
)

$configLines |
    Set-Content `
        -Path $avdConfig `
        -Encoding ASCII

Write-Host ""
Write-Host "Fast configuration applied."

# ============================================================
# STOP OLD EMULATOR
# ============================================================

Write-Host ""
Write-Host "Checking old emulator processes..."

$oldProcesses = Get-Process `
    -Name emulator `
    -ErrorAction SilentlyContinue

if ($oldProcesses) {

    Write-Host ""
    Write-Host "Stopping old emulator process..."

    $oldProcesses |
        Stop-Process `
            -Force `
            -ErrorAction SilentlyContinue

    Start-Sleep -Seconds 3
}

# ============================================================
# ADB - CLEAN START
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " STARTING ADB"
Write-Host "============================================================"

# ------------------------------------------------------------
# 10061 FIX
#
# If the daemon is not running, kill-server can return:
#
# cannot connect to 127.0.0.1:5037
# actively refused it (10061)
#
# That is NOT a fatal condition.
# ------------------------------------------------------------

Write-Host ""
Write-Host "Stopping old ADB daemon if present..."

try {

    $killOutput = & $adb kill-server 2>&1

    if ($killOutput) {
        $killOutput |
            ForEach-Object {
                Write-Host $_
            }
    }

}
catch {

    Write-Host ""
    Write-Host "No existing ADB daemon to stop."
}

Start-Sleep -Seconds 2

# ============================================================
# START ADB SERVER
# ============================================================

Write-Host ""
Write-Host "Starting ADB daemon..."

$adbStartOutput = & $adb start-server 2>&1

if ($adbStartOutput) {

    $adbStartOutput |
        ForEach-Object {
            Write-Host $_
        }
}

if ($LASTEXITCODE -ne 0) {

    Write-Host ""
    Write-Host "ADB start failed."

    Write-Host ""
    Write-Host "ADB diagnostic:"
    & $adb version 2>&1 |
        ForEach-Object {
            Write-Host $_
        }

    throw `
        "ADB server could not be started. Exit code: $LASTEXITCODE"
}

# ============================================================
# VERIFY ADB DAEMON
# ============================================================

Write-Host ""
Write-Host "Verifying ADB daemon..."

$adbVersionOutput = & $adb version 2>&1

if ($LASTEXITCODE -ne 0) {

    Write-Host ""
    Write-Host $adbVersionOutput

    throw "ADB executable is not responding."
}

Write-Host ""
Write-Host "ADB daemon ready."

# ============================================================
# CHECK PORT 5037
# ============================================================

Write-Host ""
Write-Host "Checking ADB port 5037..."

Start-Sleep -Seconds 2

$adbPortCheck = Get-NetTCPConnection `
    -LocalPort $adbPort `
    -State Listen `
    -ErrorAction SilentlyContinue

if ($adbPortCheck) {

    Write-Host ""
    Write-Host "ADB 5037 = LISTENING"

}
else {

    Write-Host ""
    Write-Host "WARNING: ADB 5037 is not visible through Get-NetTCPConnection."

    Write-Host ""
    Write-Host "Testing adb directly..."

    $testDevices = & $adb devices 2>&1

    $testDevices |
        ForEach-Object {
            Write-Host $_
        }

    if ($LASTEXITCODE -ne 0) {

        throw "ADB daemon is not responding."
    }
}

# ============================================================
# START EMULATOR
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " STARTING ANDROID EMULATOR"
Write-Host "============================================================"

$emulatorArguments = @(
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
Write-Host ($emulatorArguments -join " ")

# ============================================================
# EMULATOR START
# ============================================================

try {

    $emuProcess = Start-Process `
        -FilePath $emulator `
        -ArgumentList $emulatorArguments `
        -PassThru `
        -WindowStyle Normal

}
catch {

    throw `
        "Could not start Android Emulator: $($_.Exception.Message)"
}

if (-not $emuProcess) {

    throw "Android Emulator process could not be created."
}

Write-Host ""
Write-Host "Emulator PID:"
Write-Host $emuProcess.Id

# ============================================================
# WAIT FOR ADB DEVICE + BOOT
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " WAITING FOR ANDROID BOOT"
Write-Host "============================================================"

$bootCompleted = $false
$deviceDetected = $false

for ($i = 1; $i -le 180; $i++) {

    Start-Sleep -Seconds 2

    # --------------------------------------------------------
    # PROCESS CHECK
    # --------------------------------------------------------

    $runningEmulator = Get-Process `
        -Id $emuProcess.Id `
        -ErrorAction SilentlyContinue

    if (-not $runningEmulator) {

        Write-Host ""
        Write-Host "Emulator process stopped unexpectedly."

        break
    }

    # --------------------------------------------------------
    # ADB DEVICES
    # --------------------------------------------------------

    $devicesOutput = & $adb devices 2>&1

    $deviceLine = $devicesOutput |
        Select-String `
            "emulator-\d+\s+device"

    if ($deviceLine) {

        $deviceDetected = $true

        # ----------------------------------------------------
        # BOOT PROPERTY
        # ----------------------------------------------------

        $bootState = & $adb `
            -s "emulator-$emulatorPort" `
            shell getprop sys.boot_completed `
            2>$null

        if ($bootState -match "1") {

            $bootCompleted = $true

            Write-Host ""
            Write-Host "============================================================"
            Write-Host " ANDROID BOOT COMPLETED"
            Write-Host "============================================================"

            break
        }
    }

    # --------------------------------------------------------
    # PROGRESS
    # --------------------------------------------------------

    if (($i % 10) -eq 0) {

        Write-Host ""
        Write-Host "Waiting... $i/180"

        Write-Host ""
        Write-Host "ADB devices:"

        $devicesOutput |
            ForEach-Object {
                Write-Host $_
            }

        Write-Host ""
        Write-Host "Emulator process:"

        Get-Process `
            -Name emulator `
            -ErrorAction SilentlyContinue |
            Select-Object Id,ProcessName,CPU,WorkingSet64 |
            Format-Table -AutoSize
    }
}

# ============================================================
# FAILURE DIAGNOSTICS
# ============================================================

if (-not $bootCompleted) {

    Write-Host ""
    Write-Host "============================================================"
    Write-Host " ANDROID BOOT FAILED"
    Write-Host "============================================================"

    Write-Host ""
    Write-Host "Device detected:"
    Write-Host $deviceDetected

    Write-Host ""
    Write-Host "ADB devices:"
    & $adb devices 2>&1 |
        ForEach-Object {
            Write-Host $_
        }

    Write-Host ""
    Write-Host "Emulator processes:"

    Get-Process `
        -Name emulator `
        -ErrorAction SilentlyContinue |
        Select-Object Id,ProcessName,CPU,WorkingSet64 |
        Format-Table -AutoSize

    Write-Host ""
    Write-Host "AVD information:"

    & $avdmanager list avd 2>&1 |
        ForEach-Object {
            Write-Host $_
        }

    Write-Host ""
    Write-Host "AVD config:"

    Get-Content `
        $avdConfig `
        -ErrorAction SilentlyContinue |
        ForEach-Object {
            Write-Host $_
        }

    throw `
        "Android Emulator did not boot successfully within 360 seconds."
}

# ============================================================
# ANDROID PERFORMANCE OPTIMIZATION
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " ANDROID PERFORMANCE OPTIMIZATION"
Write-Host "============================================================"

$serial = "emulator-$emulatorPort"

Write-Host ""
Write-Host "Disabling Android animations..."

& $adb `
    -s $serial `
    shell settings put global window_animation_scale 0 `
    2>$null

& $adb `
    -s $serial `
    shell settings put global transition_animation_scale 0 `
    2>$null

& $adb `
    -s $serial `
    shell settings put global animator_duration_scale 0 `
    2>$null

Write-Host ""
Write-Host "Animations disabled."

# ============================================================
# FINAL VERIFICATION
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " FINAL ANDROID VERIFICATION"
Write-Host "============================================================"

Write-Host ""
Write-Host "ADB devices:"

& $adb devices

Write-Host ""
Write-Host "Android version:"

& $adb `
    -s $serial `
    shell getprop ro.build.version.release `
    2>$null

Write-Host ""
Write-Host "Android API:"

& $adb `
    -s $serial `
    shell getprop ro.build.version.sdk `
    2>$null

Write-Host ""
Write-Host "CPU ABI:"

& $adb `
    -s $serial `
    shell getprop ro.product.cpu.abi `
    2>$null

Write-Host ""
Write-Host "Boot completed:"

& $adb `
    -s $serial `
    shell getprop sys.boot_completed `
    2>$null

# ============================================================
# FINAL
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " ANDROID26 READY"
Write-Host "============================================================"

Write-Host ""
Write-Host "AVD:"
Write-Host "Android26"

Write-Host ""
Write-Host "Android:"
Write-Host "8.0 / API 26"

Write-Host ""
Write-Host "Image:"
Write-Host "Google APIs / x86"

Write-Host ""
Write-Host "RAM:"
Write-Host "2048 MB"

Write-Host ""
Write-Host "CPU:"
Write-Host "2 cores"

Write-Host ""
Write-Host "Resolution:"
Write-Host "600 x 960"

Write-Host ""
Write-Host "GPU:"
Write-Host "SwiftShader"

Write-Host ""
Write-Host "Animations:"
Write-Host "OFF"

Write-Host ""
Write-Host "Fullscreen:"
Write-Host "OFF"

Write-Host ""
Write-Host "ADB:"
Write-Host "READY"

Write-Host ""
Write-Host "Boot:"
Write-Host "COMPLETED"

Write-Host ""
Write-Host "============================================================"
