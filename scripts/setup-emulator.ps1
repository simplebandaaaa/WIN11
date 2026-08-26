$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================================"
Write-Host " ANDROID 26 EMULATOR - FINAL"
Write-Host "============================================================"

# ============================================================
# CONFIG
# ============================================================

$sdk = "C:\Android\android-sdk"

$emulator  = Join-Path $sdk "emulator\emulator.exe"
$sdkmanager = Join-Path $sdk "cmdline-tools\latest\bin\sdkmanager.bat"
$avdmanager = Join-Path $sdk "cmdline-tools\latest\bin\avdmanager.bat"
$adb       = Join-Path $sdk "platform-tools\adb.exe"

$avdName = "Android26"

$systemImage = "system-images;android-26;google_apis;x86"

$androidDir = Join-Path $env:USERPROFILE ".android"
$avdRoot = Join-Path $androidDir "avd"
$avdPath = Join-Path $avdRoot "$avdName.avd"
$avdConfig = Join-Path $avdPath "config.ini"

$emulatorSerial = "emulator-5554"

# ============================================================
# ENVIRONMENT
# ============================================================

$env:ANDROID_HOME = $sdk
$env:ANDROID_SDK_ROOT = $sdk

$env:PATH = `
    "$sdk\platform-tools;$sdk\emulator;$sdk\cmdline-tools\latest\bin;$env:PATH"

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

if (-not (Test-Path $adb)) {
    throw "adb.exe not found: $adb"
}

Write-Host "emulator.exe : OK"
Write-Host "sdkmanager   : OK"
Write-Host "avdmanager   : OK"
Write-Host "adb.exe      : OK"

# ============================================================
# SYSTEM IMAGE CHECK
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
    Write-Host "Android 26 Google APIs x86 image = READY"

}
else {

    Write-Host ""
    Write-Host "Android 26 image missing."
    Write-Host "Installing..."

    & cmd.exe /c "`"$sdkmanager`" `"$systemImage`"" 2>&1 |
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
# AVD CHECK
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " CHECKING AVD"
Write-Host "============================================================"

if (Test-Path $avdConfig) {

    Write-Host ""
    Write-Host "Android26 AVD already exists."
    Write-Host $avdPath

}
else {

    Write-Host ""
    Write-Host "Android26 AVD not found."
    Write-Host "Creating AVD..."

    # IMPORTANT:
    # ASCII "no" through cmd.exe prevents BOM problem.

    $createCommand = `
        "echo no|`"$avdmanager`" create avd -n $avdName -k `"$systemImage`" -d pixel --force"

    & cmd.exe /c $createCommand 2>&1 |
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
Write-Host " VERIFYING AVD"
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
    Write-Host "config.ini not found immediately."
    Write-Host "Checking avdmanager..."

    $avdOutput = & cmd.exe /c "`"$avdmanager`" list avd" 2>&1

    $avdText = $avdOutput | Out-String

    Write-Host ""
    Write-Host $avdText

    Start-Sleep -Seconds 2

    if (Test-Path $avdConfig) {

        Write-Host ""
        Write-Host "Android26 AVD verified after refresh."

    }
    elseif ($avdText -match "(?m)^\s*Name:\s*Android26\s*$") {

        if (Test-Path $avdPath) {

            Write-Host ""
            Write-Host "Android26 confirmed by avdmanager."

        }
        else {

            throw "Android26 listed but AVD directory is missing."
        }

    }
    else {

        throw "Android26 AVD could not be verified."
    }
}

# ============================================================
# FAST AVD CONFIG
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
Write-Host "Fast settings applied."

# ============================================================
# STOP OLD EMULATOR
# ============================================================

Write-Host ""
Write-Host "Checking old emulator..."

$oldEmulator = Get-Process `
    -Name emulator `
    -ErrorAction SilentlyContinue

if ($oldEmulator) {

    Write-Host ""
    Write-Host "Stopping old emulator..."

    $oldEmulator |
        Stop-Process `
            -Force `
            -ErrorAction SilentlyContinue

    Start-Sleep -Seconds 3
}

# ============================================================
# ADB CLEANUP
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " STARTING ADB"
Write-Host "============================================================"

Write-Host ""
Write-Host "Stopping old ADB daemon if present..."

# NEVER call adb directly here.
# cmd.exe prevents PowerShell NativeCommandError.

& cmd.exe /c "`"$adb`" kill-server" 2>&1 |
    ForEach-Object {
        Write-Host $_
    }

Start-Sleep -Seconds 2

# ============================================================
# START ADB
# ============================================================

Write-Host ""
Write-Host "Starting ADB daemon..."

$adbStartOutput = `
    & cmd.exe /c "`"$adb`" start-server" 2>&1

$adbStartOutput |
    ForEach-Object {
        Write-Host $_
    }

# ADB writes normal startup information to stderr.
# cmd.exe gives us the actual process exit code.

$adbExit = $LASTEXITCODE

if ($adbExit -ne 0) {

    Write-Host ""
    Write-Host "ADB start failed."
    Write-Host "Exit code:"
    Write-Host $adbExit

    Write-Host ""
    Write-Host "ADB version:"

    & cmd.exe /c "`"$adb`" version" 2>&1 |
        ForEach-Object {
            Write-Host $_
        }

    throw "ADB server could not be started."
}

Start-Sleep -Seconds 2

# ============================================================
# VERIFY ADB
# ============================================================

Write-Host ""
Write-Host "Verifying ADB daemon..."

$adbDevices = `
    & cmd.exe /c "`"$adb`" devices" 2>&1

$adbDevices |
    ForEach-Object {
        Write-Host $_
    }

$adbDevicesExit = $LASTEXITCODE

if ($adbDevicesExit -ne 0) {

    throw "ADB daemon is not responding."
}

Write-Host ""
Write-Host "ADB server ready."

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

try {

    $emuProcess = Start-Process `
        -FilePath $emulator `
        -ArgumentList $emulatorArguments `
        -PassThru `
        -WindowStyle Normal

}
catch {

    throw "Could not start emulator: $($_.Exception.Message)"
}

if (-not $emuProcess) {
    throw "Emulator process was not created."
}

Write-Host ""
Write-Host "Emulator PID:"
Write-Host $emuProcess.Id

# ============================================================
# WAIT FOR DEVICE
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " WAITING FOR ANDROID EMULATOR"
Write-Host "============================================================"

$deviceDetected = $false
$bootCompleted = $false

for ($i = 1; $i -le 180; $i++) {

    Start-Sleep -Seconds 2

    # --------------------------------------------------------
    # PROCESS CHECK
    # --------------------------------------------------------

    $processCheck = Get-Process `
        -Id $emuProcess.Id `
        -ErrorAction SilentlyContinue

    if (-not $processCheck) {

        Write-Host ""
        Write-Host "Emulator process stopped."

        break
    }

    # --------------------------------------------------------
    # ADB DEVICES
    # --------------------------------------------------------

    $devices = `
        & cmd.exe /c "`"$adb`" devices" 2>&1

    $deviceLine = $devices |
        Select-String "emulator-\d+\s+device"

    if ($deviceLine) {

        if (-not $deviceDetected) {

            $deviceDetected = $true

            Write-Host ""
            Write-Host "Android emulator detected."

        }

        # ----------------------------------------------------
        # BOOT CHECK
        # ----------------------------------------------------

        $boot = `
            & cmd.exe /c "`"$adb`" -s $emulatorSerial shell getprop sys.boot_completed" 2>$null

        if ($boot -match "1") {

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

        $devices |
            ForEach-Object {
                Write-Host $_
            }

        Write-Host ""
        Write-Host "Emulator process:"

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
# BOOT FAILURE DIAGNOSTICS
# ============================================================

if (-not $bootCompleted) {

    Write-Host ""
    Write-Host "============================================================"
    Write-Host " EMULATOR BOOT FAILED"
    Write-Host "============================================================"

    Write-Host ""
    Write-Host "Device detected:"
    Write-Host $deviceDetected

    Write-Host ""
    Write-Host "ADB devices:"

    & cmd.exe /c "`"$adb`" devices" 2>&1 |
        ForEach-Object {
            Write-Host $_
        }

    Write-Host ""
    Write-Host "Running emulator processes:"

    Get-Process `
        -Name emulator `
        -ErrorAction SilentlyContinue |
        Select-Object `
            Id,
            ProcessName,
            CPU,
            WorkingSet64 |
        Format-Table -AutoSize

    Write-Host ""
    Write-Host "AVD list:"

    & cmd.exe /c "`"$avdmanager`" list avd" 2>&1 |
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
        "Android Emulator did not become ready."
}

# ============================================================
# ANDROID PERFORMANCE
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " OPTIMIZING ANDROID"
Write-Host "============================================================"

Write-Host ""
Write-Host "Disabling animations..."

& cmd.exe /c `
    "`"$adb`" -s $emulatorSerial shell settings put global window_animation_scale 0" `
    2>&1 |
    Out-Null

& cmd.exe /c `
    "`"$adb`" -s $emulatorSerial shell settings put global transition_animation_scale 0" `
    2>&1 |
    Out-Null

& cmd.exe /c `
    "`"$adb`" -s $emulatorSerial shell settings put global animator_duration_scale 0" `
    2>&1 |
    Out-Null

Write-Host ""
Write-Host "Animations OFF."

# ============================================================
# FINAL VERIFICATION
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " FINAL VERIFICATION"
Write-Host "============================================================"

Write-Host ""
Write-Host "ADB devices:"

& cmd.exe /c "`"$adb`" devices" 2>&1 |
    ForEach-Object {
        Write-Host $_
    }

Write-Host ""
Write-Host "Android version:"

& cmd.exe /c `
    "`"$adb`" -s $emulatorSerial shell getprop ro.build.version.release" `
    2>&1 |
    ForEach-Object {
        Write-Host $_
    }

Write-Host ""
Write-Host "Android API:"

& cmd.exe /c `
    "`"$adb`" -s $emulatorSerial shell getprop ro.build.version.sdk" `
    2>&1 |
    ForEach-Object {
        Write-Host $_
    }

Write-Host ""
Write-Host "CPU ABI:"

& cmd.exe /c `
    "`"$adb`" -s $emulatorSerial shell getprop ro.product.cpu.abi" `
    2>&1 |
    ForEach-Object {
        Write-Host $_
    }

Write-Host ""
Write-Host "Boot status:"

& cmd.exe /c `
    "`"$adb`" -s $emulatorSerial shell getprop sys.boot_completed" `
    2>&1 |
    ForEach-Object {
        Write-Host $_
    }

# ============================================================
# SUCCESS
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
