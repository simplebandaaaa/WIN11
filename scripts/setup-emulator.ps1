$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================================"
Write-Host " ANDROID 26 EMULATOR - NO ADB"
Write-Host "============================================================"

# ============================================================
# CONFIGURATION
# ============================================================

$sdk = "C:\Android\android-sdk"

$emulator  = Join-Path $sdk "emulator\emulator.exe"
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

Write-Host ""
Write-Host "SDK:"
Write-Host $sdk

Write-Host ""
Write-Host "AVD:"
Write-Host $avdName

Write-Host ""
Write-Host "ADB:"
Write-Host "DISABLED"

# ============================================================
# CHECK EMULATOR
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " CHECKING EMULATOR"
Write-Host "============================================================"

if (-not (Test-Path $emulator)) {
    throw "emulator.exe not found: $emulator"
}

Write-Host ""
Write-Host "emulator.exe = OK"

# ============================================================
# CHECK SYSTEM IMAGE
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
    Write-Host "Android 26 Google APIs x86 = READY"

}
else {

    Write-Host ""
    Write-Host "Android 26 image missing."
    Write-Host "Installing..."

    if (-not (Test-Path $sdkmanager)) {
        throw "sdkmanager not found: $sdkmanager"
    }

    & cmd.exe /c `
        "`"$sdkmanager`" `"$systemImage`"" |
        ForEach-Object {
            Write-Host $_
        }

    if (-not (Test-Path $imagePath)) {
        throw "Android 26 system image installation failed."
    }

    Write-Host ""
    Write-Host "Android 26 image installed."
}

# ============================================================
# CHECK AVD
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " CHECKING ANDROID26 AVD"
Write-Host "============================================================"

if (Test-Path $avdConfig) {

    Write-Host ""
    Write-Host "Android26 AVD already exists."
    Write-Host $avdPath

}
else {

    Write-Host ""
    Write-Host "Android26 AVD not found."
    Write-Host "Creating..."

    if (-not (Test-Path $avdmanager)) {
        throw "avdmanager not found: $avdmanager"
    }

    # ASCII input through cmd.exe.
    # Prevents the previous BOM/no problem.

    $createCommand = `
        "echo no|`"$avdmanager`" create avd -n $avdName -k `"$systemImage`" -d pixel --force"

    & cmd.exe /c $createCommand |
        ForEach-Object {
            Write-Host $_
        }

    Start-Sleep -Seconds 3
}

# ============================================================
# AVD VERIFICATION
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " VERIFYING ANDROID26"
Write-Host "============================================================"

Start-Sleep -Seconds 2

if (Test-Path $avdConfig) {

    Write-Host ""
    Write-Host "Android26 AVD verified."
    Write-Host "Path:"
    Write-Host $avdPath

}
else {

    Write-Host ""
    Write-Host "config.ini not found."

    Write-Host ""
    Write-Host "Checking avdmanager..."

    $avdOutput = `
        & cmd.exe /c "`"$avdmanager`" list avd" 2>&1

    $avdText = $avdOutput | Out-String

    Write-Host ""
    Write-Host $avdText

    Start-Sleep -Seconds 2

    if (Test-Path $avdConfig) {

        Write-Host ""
        Write-Host "Android26 found after refresh."

    }
    elseif ($avdText -match "(?m)^\s*Name:\s*Android26\s*$") {

        if (-not (Test-Path $avdPath)) {
            throw "Android26 listed but directory is missing."
        }

        Write-Host ""
        Write-Host "Android26 confirmed."

    }
    else {

        throw "Android26 AVD could not be verified."
    }
}

# ============================================================
# FAST CONFIGURATION
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " APPLYING FAST SETTINGS"
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
Write-Host "============================================================"
Write-Host " CLEANING OLD EMULATOR"
Write-Host "============================================================"

$oldEmulator = Get-Process `
    -Name emulator `
    -ErrorAction SilentlyContinue

if ($oldEmulator) {

    Write-Host ""
    Write-Host "Stopping existing emulator..."

    $oldEmulator |
        Stop-Process `
            -Force `
            -ErrorAction SilentlyContinue

    Start-Sleep -Seconds 3
}

# ============================================================
# NO ADB
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " ADB DISABLED"
Write-Host "============================================================"

Write-Host ""
Write-Host "ADB is completely removed from this setup."
Write-Host "No adb.exe"
Write-Host "No tcp:5037"
Write-Host "No kill-server"
Write-Host "No start-server"
Write-Host "No adb device polling"

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

try {

    $emuProcess = Start-Process `
        -FilePath $emulator `
        -ArgumentList $arguments `
        -PassThru `
        -WindowStyle Normal

}
catch {

    throw `
        "Could not start Android Emulator: $($_.Exception.Message)"
}

if (-not $emuProcess) {
    throw "Emulator process was not created."
}

Write-Host ""
Write-Host "Emulator PID:"
Write-Host $emuProcess.Id

# ============================================================
# WAIT FOR EMULATOR PROCESS
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " WAITING FOR EMULATOR"
Write-Host "============================================================"

$emulatorStarted = $false

for ($i = 1; $i -le 120; $i++) {

    Start-Sleep -Seconds 2

    $process = Get-Process `
        -Id $emuProcess.Id `
        -ErrorAction SilentlyContinue

    if ($process) {

        if (-not $emulatorStarted) {

            $emulatorStarted = $true

            Write-Host ""
            Write-Host "Android Emulator process is running."

        }

    }
    else {

        Write-Host ""
        Write-Host "Emulator process stopped unexpectedly."

        break
    }

    if (($i % 10) -eq 0) {

        Write-Host ""
        Write-Host "Waiting... $i/120"

        Write-Host ""
        Write-Host "Emulator process status:"

        Get-Process `
            -Name emulator `
            -ErrorAction SilentlyContinue |
            Select-Object `
                Id,
                ProcessName,
                CPU,
                WorkingSet64 |
            Format-Table -AutoSize
    }
}

# ============================================================
# PROCESS DIAGNOSTICS
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " EMULATOR DIAGNOSTICS"
Write-Host "============================================================"

$currentProcess = Get-Process `
    -Id $emuProcess.Id `
    -ErrorAction SilentlyContinue

if ($currentProcess) {

    Write-Host ""
    Write-Host "Emulator process:"
    Write-Host "RUNNING"

    Write-Host ""
    Write-Host "PID:"
    Write-Host $currentProcess.Id

    Write-Host ""
    Write-Host "CPU:"
    Write-Host $currentProcess.CPU

    Write-Host ""
    Write-Host "Memory:"
    Write-Host $currentProcess.WorkingSet64

}
else {

    Write-Host ""
    Write-Host "Emulator process:"
    Write-Host "STOPPED"

    Write-Host ""
    Write-Host "AVD:"
    & cmd.exe /c "`"$avdmanager`" list avd" 2>&1 |
        ForEach-Object {
            Write-Host $_
        }

    throw "Android Emulator stopped before becoming ready."
}

# ============================================================
# FINAL
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " ANDROID26 EMULATOR STARTED"
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
Write-Host "Resolution:"
Write-Host "600 x 960"

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
Write-Host "Animations:"
Write-Host "OFF"

Write-Host ""
Write-Host "Fullscreen:"
Write-Host "OFF"

Write-Host ""
Write-Host "ADB:"
Write-Host "DISABLED"

Write-Host ""
Write-Host "Emulator process:"
Write-Host "RUNNING"

Write-Host ""
Write-Host "============================================================"
