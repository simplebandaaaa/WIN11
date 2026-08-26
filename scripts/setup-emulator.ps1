$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================================"
Write-Host " ANDROID 26 EMULATOR - FAST SETUP"
Write-Host "============================================================"

# ============================================================
# CONFIGURATION
# ============================================================

$sdk = "C:\Android\android-sdk"

$emulator  = Join-Path $sdk "emulator\emulator.exe"
$sdkmanager = Join-Path $sdk "cmdline-tools\latest\bin\sdkmanager.bat"
$avdmanager = Join-Path $sdk "cmdline-tools\latest\bin\avdmanager.bat"
$adb = Join-Path $sdk "platform-tools\adb.exe"

$avdName = "Android26"

$systemImage = "system-images;android-26;google_apis;x86"

$androidDir = Join-Path $env:USERPROFILE ".android"
$avdDir = Join-Path $androidDir "avd"
$avdPath = Join-Path $avdDir "$avdName.avd"
$avdConfig = Join-Path $avdPath "config.ini"

# ============================================================
# ENVIRONMENT
# ============================================================

$env:ANDROID_HOME = $sdk
$env:ANDROID_SDK_ROOT = $sdk

$env:PATH = "$sdk\platform-tools;$sdk\emulator;$sdk\cmdline-tools\latest\bin;$env:PATH"

New-Item -ItemType Directory -Path $androidDir -Force | Out-Null
New-Item -ItemType Directory -Path $avdDir -Force | Out-Null

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
# CHECK TOOLS
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

Write-Host "Emulator: OK"
Write-Host "sdkmanager: OK"
Write-Host "avdmanager: OK"
Write-Host "ADB: OK"

# ============================================================
# ACCEPT LICENSES
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " ANDROID LICENSES"
Write-Host "============================================================"

cmd.exe /c "echo y|`"$sdkmanager`" --licenses" 2>&1 | Out-Host

# ============================================================
# INSTALL SYSTEM IMAGE
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " CHECKING ANDROID 26 IMAGE"
Write-Host "============================================================"

$packageInstalled = $false

$packagePath = Join-Path $sdk $systemImage.Replace(";","\")

if (Test-Path $packagePath) {
    $packageInstalled = $true
}

if ($packageInstalled) {

    Write-Host ""
    Write-Host "Android 26 x86 Google APIs image already installed."

}
else {

    Write-Host ""
    Write-Host "Installing Android 26 x86 Google APIs image..."

    cmd.exe /c "`"$sdkmanager`" `"$systemImage`""

    if ($LASTEXITCODE -ne 0) {

        Write-Host ""
        Write-Host "sdkmanager returned exit code:"
        Write-Host $LASTEXITCODE

        throw "Android 26 system image installation failed."

    }
}

# ============================================================
# FIND EXISTING AVD
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " CHECKING EXISTING AVD"
Write-Host "============================================================"

$existingConfig = Test-Path $avdConfig

if ($existingConfig) {

    Write-Host ""
    Write-Host "Existing Android26 AVD found:"
    Write-Host $avdPath

}
else {

    Write-Host ""
    Write-Host "No existing Android26 AVD found."
}

# ============================================================
# CREATE AVD IF NEEDED
# ============================================================

if (-not $existingConfig) {

    Write-Host ""
    Write-Host "============================================================"
    Write-Host " CREATING ANDROID26 AVD"
    Write-Host "============================================================"

    # IMPORTANT:
    # Use cmd.exe + ASCII input.
    # This avoids the previous BOM problem:
    # "﻿no is not a valid reply"

    $createCmd = `
        "echo no | `"$avdmanager`" create avd -n $avdName -k `"$systemImage`" -d pixel --force"

    Write-Host ""
    Write-Host "Creating AVD..."

    cmd.exe /c $createCmd 2>&1 | Out-Host

    $createExit = $LASTEXITCODE

    Write-Host ""
    Write-Host "avdmanager exit code:"
    Write-Host $createExit

    # Do NOT trust only the exit code.
    # Check the actual AVD directory below.
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

}
else {

    Write-Host ""
    Write-Host "AVD directory was not found."

    Write-Host ""
    Write-Host "Expected:"
    Write-Host $avdPath

    Write-Host ""
    Write-Host "Checking avdmanager output..."

    $avdOutput = & $avdmanager list avd 2>&1
    $avdText = $avdOutput | Out-String

    Write-Host ""
    Write-Host $avdText

    # Sometimes avdmanager knows the AVD but the directory check
    # happens before filesystem refresh.
    if ($avdText -match "(?m)^\s*Name:\s*Android26\s*$") {

        Write-Host ""
        Write-Host "avdmanager confirms Android26 exists."

        if (Test-Path $avdPath) {

            Write-Host ""
            Write-Host "AVD directory now available."

        }
        else {

            throw "Android26 is listed by avdmanager but its AVD directory is unavailable."
        }

    }
    else {

        throw "Android26 AVD could not be verified."
    }
}

# ============================================================
# READ EXISTING CONFIG
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " CONFIGURING FAST MODE"
Write-Host "============================================================"

if (-not (Test-Path $avdConfig)) {
    throw "AVD config.ini does not exist: $avdConfig"
}

Write-Host ""
Write-Host "Config file:"
Write-Host $avdConfig

# ============================================================
# FAST HARDWARE CONFIGURATION
# ============================================================

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
Write-Host "Checking old emulator process..."

$oldEmulators = Get-Process emulator `
    -ErrorAction SilentlyContinue

if ($oldEmulators) {

    Write-Host ""
    Write-Host "Stopping old emulator process..."

    $oldEmulators |
        Stop-Process -Force -ErrorAction SilentlyContinue

    Start-Sleep -Seconds 2
}

# ============================================================
# START ADB
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " STARTING ADB"
Write-Host "============================================================"

& $adb kill-server 2>$null

Start-Sleep -Seconds 1

& $adb start-server 2>&1 | Out-Host

if ($LASTEXITCODE -ne 0) {

    Write-Host ""
    Write-Host "WARNING: ADB start returned:"
    Write-Host $LASTEXITCODE

}
else {

    Write-Host ""
    Write-Host "ADB server ready."

}

# ============================================================
# EMULATOR LOG
# ============================================================

$emuLog = Join-Path $env:TEMP "Android26-emulator.log"

if (Test-Path $emuLog) {
    Remove-Item $emuLog -Force -ErrorAction SilentlyContinue
}

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

# ============================================================
# START PROCESS
# ============================================================

$emuProcess = Start-Process `
    -FilePath $emulator `
    -ArgumentList $arguments `
    -PassThru `
    -WindowStyle Normal

Write-Host ""
Write-Host "Emulator PID:"
Write-Host $emuProcess.Id

# ============================================================
# WAIT FOR ADB DEVICE
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " WAITING FOR ANDROID EMULATOR"
Write-Host "============================================================"

$bootCompleted = $false

for ($i = 1; $i -le 180; $i++) {

    Start-Sleep -Seconds 2

    # Check emulator process
    $emuAlive = Get-Process `
        -Id $emuProcess.Id `
        -ErrorAction SilentlyContinue

    if (-not $emuAlive) {

        Write-Host ""
        Write-Host "WARNING: Emulator process stopped."

        break
    }

    # Check ADB
    $devices = & $adb devices 2>$null

    $deviceFound = $devices |
        Select-String "emulator-\d+\s+device"

    if ($deviceFound) {

        $bootState = & $adb `
            -s emulator-5554 `
            shell getprop sys.boot_completed `
            2>$null

        if ($bootState -match "1") {

            Write-Host ""
            Write-Host "============================================================"
            Write-Host " ANDROID BOOT COMPLETED"
            Write-Host "============================================================"

            $bootCompleted = $true

            break
        }
    }

    if (($i % 10) -eq 0) {

        Write-Host ""
        Write-Host "Waiting... $i/180"

        Write-Host ""
        Write-Host "ADB devices:"

        & $adb devices

        Write-Host ""
        Write-Host "Emulator process:"

        Get-Process emulator `
            -ErrorAction SilentlyContinue |
            Select-Object Id,ProcessName,CPU,WorkingSet64 |
            Format-Table -AutoSize
    }
}

# ============================================================
# DIAGNOSTICS IF BOOT FAILED
# ============================================================

if (-not $bootCompleted) {

    Write-Host ""
    Write-Host "============================================================"
    Write-Host " EMULATOR BOOT FAILED"
    Write-Host "============================================================"

    Write-Host ""
    Write-Host "ADB devices:"
    & $adb devices

    Write-Host ""
    Write-Host "Emulator process:"
    Get-Process emulator `
        -ErrorAction SilentlyContinue |
        Select-Object Id,ProcessName,CPU,WorkingSet64 |
        Format-Table -AutoSize

    Write-Host ""
    Write-Host "AVD list:"
    & $avdmanager list avd

    Write-Host ""
    Write-Host "AVD config:"
    Get-Content $avdConfig `
        -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host "Recent emulator log if available:"

    if (Test-Path $emuLog) {

        Get-Content $emuLog `
            -Tail 100 `
            -ErrorAction SilentlyContinue

    }
    else {

        Write-Host "No emulator log file available."

    }

    throw "Android Emulator did not boot successfully."
}

# ============================================================
# DISABLE ANDROID ANIMATIONS
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " OPTIMIZING ANDROID"
Write-Host "============================================================"

& $adb -s emulator-5554 `
    shell settings put global window_animation_scale 0 `
    2>$null

& $adb -s emulator-5554 `
    shell settings put global transition_animation_scale 0 `
    2>$null

& $adb -s emulator-5554 `
    shell settings put global animator_duration_scale 0 `
    2>$null

# ============================================================
# VERIFY FINAL STATE
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " FINAL VERIFICATION"
Write-Host "============================================================"

Write-Host ""
Write-Host "ADB devices:"

& $adb devices

Write-Host ""
Write-Host "Android version:"

& $adb -s emulator-5554 `
    shell getprop ro.build.version.release `
    2>$null

Write-Host ""
Write-Host "SDK/API:"

& $adb -s emulator-5554 `
    shell getprop ro.build.version.sdk `
    2>$null

Write-Host ""
Write-Host "ABI:"

& $adb -s emulator-5554 `
    shell getprop ro.product.cpu.abi `
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
Write-Host "Boot:"
Write-Host "COMPLETED"

Write-Host ""
Write-Host "============================================================"
