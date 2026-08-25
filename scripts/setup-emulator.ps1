$ErrorActionPreference = "Stop"

# ============================================================
# Android 8.0 / API 26 Emulator
# GitHub Windows Runner
# Browser-control preparation + diagnostics
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " ANDROID 26 EMULATOR SETUP"
Write-Host "============================================================"

# ============================================================
# CONFIG
# ============================================================

$Sdk = "C:\Android\android-sdk"

$env:ANDROID_HOME = $Sdk
$env:ANDROID_SDK_ROOT = $Sdk

$AvdName = "Android26"
$SystemImage = "system-images;android-26;google_apis;x86"

$AvdRoot = "$env:USERPROFILE\.android\avd"
$AvdDir = "$AvdRoot\$AvdName.avd"
$AvdIni = "$AvdRoot\$AvdName.ini"

$EmulatorLog = "$env:TEMP\Android26-emulator.log"
$AdbLog = "$env:TEMP\Android26-adb.log"

# ============================================================
# HELPER: RUN COMMAND WITHOUT POWERSHELL ABORTING ON STDERR
# ============================================================

function Invoke-SafeCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $false)]
        [string[]]$Arguments = @()
    )

    $old = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    $output = & $FilePath @Arguments 2>&1
    $exitCode = $LASTEXITCODE

    $ErrorActionPreference = $old

    return @{
        Output   = @($output)
        ExitCode = $exitCode
    }
}

# ============================================================
# SDK DIRECTORY
# ============================================================

Write-Host ""
Write-Host "[1/12] Checking Android SDK..."

if (-not (Test-Path $Sdk)) {

    New-Item `
        -ItemType Directory `
        -Path $Sdk `
        -Force | Out-Null
}

Write-Host "SDK: $Sdk"

# ============================================================
# SDK MANAGER
# ============================================================

Write-Host ""
Write-Host "[2/12] Locating sdkmanager..."

$sdkmanager = $null

$candidates = @(
    "$Sdk\cmdline-tools\latest\bin\sdkmanager.bat",
    "$Sdk\cmdline-tools\bin\sdkmanager.bat",
    "$Sdk\tools\bin\sdkmanager.bat"
)

foreach ($path in $candidates) {

    if (Test-Path $path) {

        $sdkmanager = $path
        break
    }
}

if (-not $sdkmanager) {

    $found = Get-ChildItem `
        -Path $Sdk `
        -Filter "sdkmanager.bat" `
        -Recurse `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($found) {
        $sdkmanager = $found.FullName
    }
}

if (-not $sdkmanager) {
    throw "sdkmanager.bat was not found."
}

Write-Host "sdkmanager: $sdkmanager"

# ============================================================
# INSTALL REQUIRED COMPONENTS
# ============================================================

Write-Host ""
Write-Host "[3/12] Installing Android components..."

$packages = @(
    "platform-tools",
    "emulator",
    "platforms;android-26",
    "system-images;android-26;google_apis;x86"
)

foreach ($package in $packages) {

    Write-Host ""
    Write-Host "Installing: $package"

    $result = Invoke-SafeCommand `
        -FilePath $sdkmanager `
        -Arguments @($package)

    $result.Output | ForEach-Object {
        Write-Host $_
    }

    if ($result.ExitCode -ne 0) {

        throw "Failed installing Android package: $package"
    }
}

# ============================================================
# LOCATE ADB
# ============================================================

Write-Host ""
Write-Host "[4/12] Locating ADB..."

$adb = "$Sdk\platform-tools\adb.exe"

if (-not (Test-Path $adb)) {
    throw "adb.exe was not found: $adb"
}

Write-Host "ADB: $adb"

# ============================================================
# LOCATE EMULATOR
# ============================================================

$emulator = "$Sdk\emulator\emulator.exe"

if (-not (Test-Path $emulator)) {
    throw "emulator.exe was not found: $emulator"
}

Write-Host "Emulator: $emulator"

# ============================================================
# LOCATE AVD MANAGER
# ============================================================

Write-Host ""
Write-Host "[5/12] Locating avdmanager..."

$avdmanager = $null

$candidates = @(
    "$Sdk\cmdline-tools\latest\bin\avdmanager.bat",
    "$Sdk\cmdline-tools\bin\avdmanager.bat",
    "$Sdk\tools\bin\avdmanager.bat"
)

foreach ($path in $candidates) {

    if (Test-Path $path) {

        $avdmanager = $path
        break
    }
}

if (-not $avdmanager) {

    $found = Get-ChildItem `
        -Path $Sdk `
        -Filter "avdmanager.bat" `
        -Recurse `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($found) {
        $avdmanager = $found.FullName
    }
}

if (-not $avdmanager) {
    throw "avdmanager.bat was not found."
}

Write-Host "avdmanager: $avdmanager"

# ============================================================
# AVD ROOT
# ============================================================

if (-not (Test-Path $AvdRoot)) {

    New-Item `
        -ItemType Directory `
        -Path $AvdRoot `
        -Force | Out-Null
}

# ============================================================
# HARDWARE PROFILE
# ============================================================

Write-Host ""
Write-Host "[6/12] Finding Android hardware profile..."

$result = Invoke-SafeCommand `
    -FilePath $avdmanager `
    -Arguments @("list", "device")

$deviceOutput = $result.Output

$DeviceName = $null

if ($deviceOutput -match "(?im)^\s*id:\s*pixel\b") {

    $DeviceName = "pixel"
}

if (-not $DeviceName) {

    foreach ($fallback in @(
        "Nexus 5",
        "Nexus 5X",
        "Nexus 6P",
        "Nexus 7"
    )) {

        if ($deviceOutput -match [regex]::Escape($fallback)) {

            $DeviceName = $fallback
            break
        }
    }
}

if (-not $DeviceName) {

    throw "No suitable Android hardware profile found."
}

Write-Host "Selected device: $DeviceName"

# ============================================================
# STOP OLD EMULATOR
# ============================================================

Write-Host ""
Write-Host "[7/12] Stopping previous emulator..."

Get-Process `
    -Name "emulator" `
    -ErrorAction SilentlyContinue |
    Stop-Process `
        -Force `
        -ErrorAction SilentlyContinue

Start-Sleep -Seconds 2

# ============================================================
# REMOVE OLD AVD
# ============================================================

Write-Host ""
Write-Host "Removing previous Android26 AVD..."

$result = Invoke-SafeCommand `
    -FilePath $avdmanager `
    -Arguments @(
        "delete",
        "avd",
        "-n",
        $AvdName
    )

$result.Output | ForEach-Object {
    Write-Host $_
}

if (Test-Path $AvdDir) {

    Remove-Item `
        -Path $AvdDir `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue
}

if (Test-Path $AvdIni) {

    Remove-Item `
        -Path $AvdIni `
        -Force `
        -ErrorAction SilentlyContinue
}

# ============================================================
# CREATE AVD
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " Creating Android26 AVD"
Write-Host "============================================================"

# Do NOT pipe "no" through PowerShell.
# This avoids the previous BOM/Unicode issue:
# "﻿no is not a valid reply"

$createArgs = @(
    "create",
    "avd",
    "-n",
    $AvdName,
    "-k",
    $SystemImage,
    "-d",
    $DeviceName,
    "--force"
)

$result = Invoke-SafeCommand `
    -FilePath $avdmanager `
    -Arguments $createArgs

$result.Output | ForEach-Object {
    Write-Host $_
}

if ($result.ExitCode -ne 0) {

    throw "Android26 AVD creation failed. Exit code: $($result.ExitCode)"
}

# ============================================================
# VERIFY AVD FILES
# ============================================================

Write-Host ""
Write-Host "Verifying AVD..."

if (-not (Test-Path $AvdDir)) {
    throw "AVD directory was not created: $AvdDir"
}

if (-not (Test-Path "$AvdDir\config.ini")) {
    throw "AVD config.ini was not created."
}

Write-Host "AVD directory:"
Write-Host $AvdDir

# ============================================================
# CONFIGURE AVD
# ============================================================

Write-Host ""
Write-Host "Applying lightweight configuration..."

$configFile = "$AvdDir\config.ini"

$config = Get-Content `
    -Path $configFile `
    -ErrorAction SilentlyContinue

$settings = [ordered]@{

    "hw.ramSize"              = "1536"
    "vm.heapSize"             = "256"
    "hw.cpu.ncore"            = "2"

    "hw.gpu.enabled"          = "yes"
    "hw.gpu.mode"             = "swiftshader_indirect"

    "hw.camera.back"          = "none"
    "hw.camera.front"         = "none"

    "showDeviceFrame"         = "no"
    "skin.dynamic"            = "no"

    "fastboot.forceColdBoot"  = "yes"

    "disk.dataPartition.size" = "2048M"

    "hw.lcd.width"            = "600"
    "hw.lcd.height"           = "960"
    "hw.lcd.density"          = "240"
}

foreach ($key in $settings.Keys) {

    $value = $settings[$key]

    $pattern = "^$([regex]::Escape($key))=.*$"

    if ($config -match $pattern) {

        $config = $config -replace `
            $pattern, `
            "$key=$value"

    }
    else {

        $config += "$key=$value"
    }
}

Set-Content `
    -Path $configFile `
    -Value $config `
    -Encoding ASCII

Write-Host "Configuration applied."

# ============================================================
# ADB ENVIRONMENT
# ============================================================

Write-Host ""
Write-Host "[8/12] Preparing ADB..."

$env:ANDROID_ADB_SERVER_PORT = "5037"

# Stop any stale ADB server.
$result = Invoke-SafeCommand `
    -FilePath $adb `
    -Arguments @("kill-server")

$result.Output | ForEach-Object {
    Write-Host $_
}

Start-Sleep -Seconds 2

# Start fresh ADB server.
$result = Invoke-SafeCommand `
    -FilePath $adb `
    -Arguments @("start-server")

$result.Output | ForEach-Object {
    Write-Host $_
}

if ($result.ExitCode -ne 0) {

    throw "ADB server failed to start. Exit code: $($result.ExitCode)"
}

Write-Host ""
Write-Host "ADB server started."

# ============================================================
# START EMULATOR
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " Starting Android Emulator"
Write-Host "============================================================"

if (Test-Path $EmulatorLog) {

    Remove-Item `
        -Path $EmulatorLog `
        -Force `
        -ErrorAction SilentlyContinue
}

$emuArgs = @(
    "-avd", $AvdName,

    "-no-snapshot",
    "-no-boot-anim",

    "-no-audio",

    "-camera-back", "none",
    "-camera-front", "none",

    "-gpu", "swiftshader_indirect",

    "-memory", "1536",
    "-cores", "2",

    "-no-metrics",

    "-verbose"
)

Write-Host ""
Write-Host "Emulator command:"
Write-Host $emulator
Write-Host ($emuArgs -join " ")

# Start emulator with stdout/stderr captured.
$emuProcess = Start-Process `
    -FilePath $emulator `
    -ArgumentList $emuArgs `
    -WorkingDirectory (Split-Path $emulator) `
    -RedirectStandardOutput $EmulatorLog `
    -RedirectStandardError $EmulatorLog `
    -WindowStyle Normal `
    -PassThru

if (-not $emuProcess) {

    throw "Could not start emulator process."
}

Write-Host ""
Write-Host "Emulator PID:"
Write-Host $emuProcess.Id

# ============================================================
# WAIT FOR EMULATOR PROCESS
# ============================================================

Write-Host ""
Write-Host "Waiting for emulator process..."

$processFound = $false

for ($i = 1; $i -le 30; $i++) {

    Start-Sleep -Seconds 2

    $process = Get-Process `
        -Id $emuProcess.Id `
        -ErrorAction SilentlyContinue

    if ($process) {

        $processFound = $true

        Write-Host "Emulator process is running."

        break
    }

    Write-Host "Process not detected... $i/30"
}

if (-not $processFound) {

    Write-Host ""
    Write-Host "Emulator process exited before ADB connection."

    if (Test-Path $EmulatorLog) {

        Write-Host ""
        Write-Host "========== EMULATOR LOG =========="
        Get-Content `
            -Path $EmulatorLog `
            -Tail 150
    }

    throw "Android Emulator process exited early."
}

# ============================================================
# WAIT FOR ADB DEVICE
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " Waiting for Android Emulator through ADB"
Write-Host "============================================================"

$deviceReady = $false

for ($i = 1; $i -le 120; $i++) {

    Start-Sleep -Seconds 2

    $result = Invoke-SafeCommand `
        -FilePath $adb `
        -Arguments @("devices", "-l")

    $devices = $result.Output

    # Print every 10 attempts for diagnostics.
    if (($i % 10) -eq 0) {

        Write-Host ""
        Write-Host "ADB status at attempt $i:"
        $devices | ForEach-Object {
            Write-Host $_
        }

        Write-Host ""
        Write-Host "Emulator process status:"

        Get-Process `
            -Name "emulator" `
            -ErrorAction SilentlyContinue |
            Select-Object Id, ProcessName, CPU, StartTime |
            Format-Table -AutoSize
    }

    $deviceLine = $devices |
        Where-Object {
            $_ -match "^emulator-\d+\s+device(\s|$)"
        }

    if ($deviceLine) {

        Write-Host ""
        Write-Host "============================================================"
        Write-Host " ADB DEVICE DETECTED"
        Write-Host "============================================================"

        $deviceLine | ForEach-Object {
            Write-Host $_
        }

        $deviceReady = $true
        break
    }

    Write-Host "Waiting... $i/120"
}

# ============================================================
# ADB FAILURE DIAGNOSTICS
# ============================================================

if (-not $deviceReady) {

    Write-Host ""
    Write-Host "============================================================"
    Write-Host " ADB DEVICE NOT DETECTED"
    Write-Host "============================================================"

    Write-Host ""
    Write-Host "----- adb devices -l -----"

    $result = Invoke-SafeCommand `
        -FilePath $adb `
        -Arguments @("devices", "-l")

    $result.Output | ForEach-Object {
        Write-Host $_
    }

    Write-Host ""
    Write-Host "----- adb get-state -----"

    $result = Invoke-SafeCommand `
        -FilePath $adb `
        -Arguments @("get-state")

    $result.Output | ForEach-Object {
        Write-Host $_
    }

    Write-Host ""
    Write-Host "----- adb version -----"

    $result = Invoke-SafeCommand `
        -FilePath $adb `
        -Arguments @("version")

    $result.Output | ForEach-Object {
        Write-Host $_
    }

    Write-Host ""
    Write-Host "----- emulator process -----"

    $processes = Get-Process `
        -Name "emulator" `
        -ErrorAction SilentlyContinue

    if ($processes) {

        $processes |
            Select-Object Id, ProcessName, CPU, StartTime |
            Format-Table -AutoSize

    }
    else {

        Write-Host "NO emulator.exe PROCESS FOUND"
    }

    Write-Host ""
    Write-Host "----- ADB server process -----"

    Get-Process `
        -Name "adb" `
        -ErrorAction SilentlyContinue |
        Select-Object Id, ProcessName, CPU, StartTime |
        Format-Table -AutoSize

    Write-Host ""
    Write-Host "----- AVD directory -----"

    Write-Host $AvdDir

    if (Test-Path $AvdDir) {

        Get-ChildItem `
            -Path $AvdDir `
            -Force |
            Select-Object Name, Length, LastWriteTime |
            Format-Table -AutoSize
    }

    # ========================================================
    # EMULATOR LOG
    # ========================================================

    Write-Host ""
    Write-Host "============================================================"
    Write-Host " EMULATOR LOG - LAST 200 LINES"
    Write-Host "============================================================"

    if (Test-Path $EmulatorLog) {

        Get-Content `
            -Path $EmulatorLog `
            -Tail 200 |
            ForEach-Object {
                Write-Host $_
            }

    }
    else {

        Write-Host "Emulator log was not created."
    }

    # ========================================================
    # WINDOWS VIRTUALIZATION CHECK
    # ========================================================

    Write-Host ""
    Write-Host "============================================================"
    Write-Host " WINDOWS VIRTUALIZATION INFORMATION"
    Write-Host "============================================================"

    try {

        Get-ComputerInfo `
            -Property `
            CsName,
            WindowsProductName,
            WindowsVersion,
            OsArchitecture |
            Format-List

    }
    catch {
        Write-Host "ComputerInfo unavailable."
    }

    # ========================================================
    # EMULATOR VERSION
    # ========================================================

    Write-Host ""
    Write-Host "============================================================"
    Write-Host " EMULATOR VERSION"
    Write-Host "============================================================"

    $result = Invoke-SafeCommand `
        -FilePath $emulator `
        -Arguments @("-version")

    $result.Output | ForEach-Object {
        Write-Host $_
    }

    throw "Android Emulator did not become available through ADB."
}

# ============================================================
# WAIT FOR ANDROID BOOT
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " Waiting for Android boot"
Write-Host "============================================================"

$booted = $false

for ($i = 1; $i -le 120; $i++) {

    Start-Sleep -Seconds 2

    $result = Invoke-SafeCommand `
        -FilePath $adb `
        -Arguments @(
            "-e",
            "shell",
            "getprop",
            "sys.boot_completed"
        )

    $boot = $result.Output -join "`n"

    if ($boot -match "(?m)^\s*1\s*$") {

        $booted = $true

        Write-Host ""
        Write-Host "Android boot completed."

        break
    }

    Write-Host "Booting... $i/120"
}

if (-not $booted) {

    Write-Host ""
    Write-Host "============================================================"
    Write-Host " ANDROID BOOT TIMEOUT"
    Write-Host "============================================================"

    Write-Host ""
    Write-Host "ADB devices:"

    $result = Invoke-SafeCommand `
        -FilePath $adb `
        -Arguments @("devices", "-l")

    $result.Output | ForEach-Object {
        Write-Host $_
    }

    Write-Host ""
    Write-Host "sys.boot_completed:"

    $result = Invoke-SafeCommand `
        -FilePath $adb `
        -Arguments @(
            "-e",
            "shell",
            "getprop",
            "sys.boot_completed"
        )

    $result.Output | ForEach-Object {
        Write-Host $_
    }

    Write-Host ""
    Write-Host "Emulator log:"

    if (Test-Path $EmulatorLog) {

        Get-Content `
            -Path $EmulatorLog `
            -Tail 200 |
            ForEach-Object {
                Write-Host $_
            }
    }

    throw "Android Emulator connected to ADB but Android did not finish booting."
}

# ============================================================
# BASIC ANDROID TEST
# ============================================================

Write-Host ""
Write-Host "Testing Android shell..."

$result = Invoke-SafeCommand `
    -FilePath $adb `
    -Arguments @(
        "-e",
        "shell",
        "getprop",
        "ro.build.version.release"
    )

Write-Host "Android version:"
$result.Output | ForEach-Object {
    Write-Host $_
}

$result = Invoke-SafeCommand `
    -FilePath $adb `
    -Arguments @(
        "-e",
        "shell",
        "getprop",
        "ro.product.cpu.abi"
    )

Write-Host ""
Write-Host "CPU ABI:"
$result.Output | ForEach-Object {
    Write-Host $_
}

# ============================================================
# FINAL SUCCESS
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " ANDROID EMULATOR READY"
Write-Host "============================================================"

Write-Host ""
Write-Host "AVD:"
Write-Host $AvdName

Write-Host ""
Write-Host "Android:"
Write-Host "8.0 / API 26"

Write-Host ""
Write-Host "ABI:"
Write-Host "x86"

Write-Host ""
Write-Host "Display:"
Write-Host "600 x 960"

Write-Host ""
Write-Host "RAM:"
Write-Host "1536 MB"

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
Write-Host "CONNECTED"

Write-Host ""
Write-Host "Emulator PID:"
Write-Host $emuProcess.Id

Write-Host ""
Write-Host "Emulator log:"
Write-Host $EmulatorLog

Write-Host ""
Write-Host "============================================================"
Write-Host " NEXT STEP: Browser bridge can start now."
Write-Host "============================================================"
