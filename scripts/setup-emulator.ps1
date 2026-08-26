$ErrorActionPreference = "Stop"

# ============================================================
# ANDROID 8.0 / API 26 EMULATOR
# Windows GitHub Actions Runner
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " ANDROID 26 EMULATOR SETUP"
Write-Host "============================================================"

# ============================================================
# CONFIGURATION
# ============================================================

$Sdk = "C:\Android\android-sdk"

$env:ANDROID_HOME = $Sdk
$env:ANDROID_SDK_ROOT = $Sdk
$env:ANDROID_AVD_HOME = "$env:USERPROFILE\.android\avd"
$env:ANDROID_ADB_SERVER_PORT = "5037"

$AvdName = "Android26"
$SystemImage = "system-images;android-26;google_apis;x86"

$AvdRoot = "$env:ANDROID_AVD_HOME"
$AvdDir = "$AvdRoot\$AvdName.avd"
$AvdIni = "$AvdRoot\$AvdName.ini"

$EmulatorStdout = "$env:TEMP\Android26-emulator-stdout.log"
$EmulatorStderr = "$env:TEMP\Android26-emulator-stderr.log"

# ============================================================
# HELPER
# ============================================================

function Invoke-SafeCommand {

    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $false)]
        [string[]]$Arguments = @()
    )

    $oldErrorAction = $ErrorActionPreference

    $ErrorActionPreference = "Continue"

    $output = & $FilePath @Arguments 2>&1

    $exitCode = $LASTEXITCODE

    $ErrorActionPreference = $oldErrorAction

    return @{
        Output = @($output)
        ExitCode = $exitCode
    }
}

# ============================================================
# SDK
# ============================================================

Write-Host ""
Write-Host "[1/13] Checking Android SDK..."

if (-not (Test-Path $Sdk)) {

    New-Item `
        -ItemType Directory `
        -Path $Sdk `
        -Force | Out-Null
}

Write-Host "SDK:"
Write-Host $Sdk

# ============================================================
# SDKMANAGER
# ============================================================

Write-Host ""
Write-Host "[2/13] Locating sdkmanager..."

$sdkmanager = $null

$candidates = @(
    "$Sdk\cmdline-tools\latest\bin\sdkmanager.bat",
    "$Sdk\cmdline-tools\bin\sdkmanager.bat",
    "$Sdk\tools\bin\sdkmanager.bat"
)

foreach ($candidate in $candidates) {

    if (Test-Path $candidate) {

        $sdkmanager = $candidate
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
    throw "sdkmanager.bat not found."
}

Write-Host "sdkmanager:"
Write-Host $sdkmanager

# ============================================================
# ADB
# ============================================================

$adb = "$Sdk\platform-tools\adb.exe"

# ============================================================
# EMULATOR
# ============================================================

$emulator = "$Sdk\emulator\emulator.exe"

# ============================================================
# AVD MANAGER
# ============================================================

Write-Host ""
Write-Host "[3/13] Locating avdmanager..."

$avdmanager = $null

$candidates = @(
    "$Sdk\cmdline-tools\latest\bin\avdmanager.bat",
    "$Sdk\cmdline-tools\bin\avdmanager.bat",
    "$Sdk\tools\bin\avdmanager.bat"
)

foreach ($candidate in $candidates) {

    if (Test-Path $candidate) {

        $avdmanager = $candidate
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
    throw "avdmanager.bat not found."
}

Write-Host "avdmanager:"
Write-Host $avdmanager

# ============================================================
# VERIFY TOOLS
# ============================================================

Write-Host ""
Write-Host "[4/13] Verifying Android tools..."

if (-not (Test-Path $adb)) {
    throw "adb.exe not found: $adb"
}

if (-not (Test-Path $emulator)) {
    throw "emulator.exe not found: $emulator"
}

Write-Host "ADB:"
Write-Host $adb

Write-Host ""
Write-Host "Emulator:"
Write-Host $emulator

# ============================================================
# INSTALL REQUIRED PACKAGES
# ============================================================

Write-Host ""
Write-Host "[5/13] Installing Android components..."

$packages = @(
    "platform-tools",
    "emulator",
    "platforms;android-26",
    "system-images;android-26;google_apis;x86"
)

foreach ($package in $packages) {

    Write-Host ""
    Write-Host "Checking/installing:"
    Write-Host $package

    $result = Invoke-SafeCommand `
        -FilePath $sdkmanager `
        -Arguments @(
            $package
        )

    $result.Output | ForEach-Object {
        Write-Host $_
    }

    if ($result.ExitCode -ne 0) {
        throw "Failed to install Android package: $package"
    }
}

# ============================================================
# AVD DIRECTORY
# ============================================================

Write-Host ""
Write-Host "[6/13] Preparing AVD directory..."

New-Item `
    -ItemType Directory `
    -Path $AvdRoot `
    -Force | Out-Null

Write-Host "AVD root:"
Write-Host $AvdRoot

# ============================================================
# DEVICE PROFILE
# ============================================================

Write-Host ""
Write-Host "Finding Android hardware profile..."

$result = Invoke-SafeCommand `
    -FilePath $avdmanager `
    -Arguments @(
        "list",
        "device"
    )

$deviceOutput = $result.Output -join "`n"

$DeviceId = "pixel"

if ($deviceOutput -notmatch "(?im)^\s*id:\s*pixel\b") {

    foreach ($fallback in @(
        "Nexus 5",
        "Nexus 5X",
        "Nexus 6P",
        "Nexus 7"
    )) {

        if ($deviceOutput -match [regex]::Escape($fallback)) {

            $DeviceId = $fallback
            break
        }
    }
}

Write-Host ""
Write-Host "Selected hardware profile:"
Write-Host $DeviceId

# ============================================================
# STOP OLD EMULATOR
# ============================================================

Write-Host ""
Write-Host "Stopping previous emulator..."

Get-Process `
    -Name "emulator" `
    -ErrorAction SilentlyContinue |
    Stop-Process `
        -Force `
        -ErrorAction SilentlyContinue

Start-Sleep -Seconds 2

# ============================================================
# DELETE OLD AVD
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
Write-Host " CREATING ANDROID26 AVD"
Write-Host "============================================================"

# IMPORTANT:
# Do NOT pipe a UTF-8 "no" into avdmanager.
# That caused the previous:
# "﻿no is not a valid reply"
#
# Instead provide the answer through StandardInput
# using ASCII bytes.

$createCommand = @"
$avdmanager create avd -n "$AvdName" -k "$SystemImage" -d "$DeviceId" --force
"@

Write-Host ""
Write-Host "Creating AVD:"
Write-Host $AvdName

$psi = New-Object `
    System.Diagnostics.ProcessStartInfo

$psi.FileName = $avdmanager
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.CreateNoWindow = $true

$psi.Arguments = "create avd -n `"$AvdName`" -k `"$SystemImage`" -d `"$DeviceId`" --force"

$avdProcess = New-Object `
    System.Diagnostics.Process

$avdProcess.StartInfo = $psi

[void]$avdProcess.Start()

# Answer the hardware-profile prompt.
# ASCII is intentional to avoid hidden UTF-8 BOM characters.

$avdProcess.StandardInput.WriteLine("no")
$avdProcess.StandardInput.Close()

$avdStdout = $avdProcess.StandardOutput.ReadToEnd()
$avdStderr = $avdProcess.StandardError.ReadToEnd()

$avdProcess.WaitForExit()

Write-Host ""
Write-Host "AVD manager output:"

if ($avdStdout) {
    Write-Host $avdStdout
}

if ($avdStderr) {
    Write-Host $avdStderr
}

if ($avdProcess.ExitCode -ne 0) {
    throw "Failed to create Android26 AVD. Exit code: $($avdProcess.ExitCode)"
}

# ============================================================
# VERIFY AVD
# ============================================================

Write-Host ""
Write-Host "Verifying AVD..."

Start-Sleep -Seconds 2

if (-not (Test-Path $AvdDir)) {
    throw "Android26 AVD directory was not created: $AvdDir"
}

if (-not (Test-Path $AvdIni)) {
    throw "Android26 AVD .ini file was not created: $AvdIni"
}

Write-Host ""
Write-Host "Android26 AVD created successfully."

Write-Host ""
Write-Host "AVD directory:"
Write-Host $AvdDir

# ============================================================
# AVD DETAILS
# ============================================================

Write-Host ""
Write-Host "Available Android Virtual Devices:"

$result = Invoke-SafeCommand `
    -FilePath $avdmanager `
    -Arguments @(
        "list",
        "avd"
    )

$result.Output | ForEach-Object {
    Write-Host $_
}

# ============================================================
# CONFIGURE AVD
# ============================================================

Write-Host ""
Write-Host "Applying emulator configuration..."

$configFile = "$AvdDir\config.ini"

if (-not (Test-Path $configFile)) {
    throw "AVD config.ini not found."
}

$config = Get-Content `
    -Path $configFile `
    -ErrorAction Stop

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

    $found = $false

    for ($index = 0; $index -lt $config.Count; $index++) {

        if ($config[$index] -match $pattern) {

            $config[$index] = "$key=$value"

            $found = $true
            break
        }
    }

    if (-not $found) {

        $config += "$key=$value"
    }
}

Set-Content `
    -Path $configFile `
    -Value $config `
    -Encoding ASCII

Write-Host "AVD configuration applied."

# ============================================================
# RESET ADB
# ============================================================

Write-Host ""
Write-Host "[7/13] Resetting ADB..."

$result = Invoke-SafeCommand `
    -FilePath $adb `
    -Arguments @(
        "kill-server"
    )

$result.Output | ForEach-Object {
    Write-Host $_
}

Start-Sleep -Seconds 2

$result = Invoke-SafeCommand `
    -FilePath $adb `
    -Arguments @(
        "start-server"
    )

$result.Output | ForEach-Object {
    Write-Host $_
}

if ($result.ExitCode -ne 0) {
    throw "ADB server failed to start."
}

Write-Host ""
Write-Host "ADB server ready."

# ============================================================
# VERIFY ADB SERVER
# ============================================================

$result = Invoke-SafeCommand `
    -FilePath $adb `
    -Arguments @(
        "devices"
    )

$result.Output | ForEach-Object {
    Write-Host $_
}

# ============================================================
# CLEAR OLD LOGS
# ============================================================

Remove-Item `
    $EmulatorStdout `
    -Force `
    -ErrorAction SilentlyContinue

Remove-Item `
    $EmulatorStderr `
    -Force `
    -ErrorAction SilentlyContinue

# ============================================================
# START EMULATOR
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " STARTING ANDROID EMULATOR"
Write-Host "============================================================"

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
Write-Host "Emulator:"
Write-Host $emulator

Write-Host ""
Write-Host "Arguments:"
Write-Host ($emuArgs -join " ")

# IMPORTANT:
# stdout and stderr MUST be different files.

$emuProcess = Start-Process `
    -FilePath $emulator `
    -ArgumentList $emuArgs `
    -WorkingDirectory (Split-Path $emulator) `
    -RedirectStandardOutput $EmulatorStdout `
    -RedirectStandardError $EmulatorStderr `
    -WindowStyle Normal `
    -PassThru

if (-not $emuProcess) {
    throw "Failed to start Android Emulator."
}

Write-Host ""
Write-Host "Emulator PID:"
Write-Host $emuProcess.Id

Write-Host ""
Write-Host "STDOUT:"
Write-Host $EmulatorStdout

Write-Host ""
Write-Host "STDERR:"
Write-Host $EmulatorStderr

# ============================================================
# CHECK PROCESS
# ============================================================

Write-Host ""
Write-Host "[8/13] Checking emulator process..."

$processRunning = $false

for ($i = 1; $i -le 30; $i++) {

    Start-Sleep -Seconds 2

    $process = Get-Process `
        -Id $emuProcess.Id `
        -ErrorAction SilentlyContinue

    if ($process) {

        $processRunning = $true

        Write-Host "Emulator process is running."
        break
    }

    Write-Host "Emulator process not detected... ${i}/30"
}

if (-not $processRunning) {

    Write-Host ""
    Write-Host "============================================================"
    Write-Host " EMULATOR EXITED EARLY"
    Write-Host "============================================================"

    Write-Host ""
    Write-Host "STDOUT:"

    if (Test-Path $EmulatorStdout) {

        Get-Content `
            -Path $EmulatorStdout `
            -Tail 150 |
            ForEach-Object {
                Write-Host $_
            }
    }

    Write-Host ""
    Write-Host "STDERR:"

    if (Test-Path $EmulatorStderr) {

        Get-Content `
            -Path $EmulatorStderr `
            -Tail 200 |
            ForEach-Object {
                Write-Host $_
            }
    }

    throw "Android Emulator process exited early."
}

# ============================================================
# WAIT FOR ADB DEVICE
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " WAITING FOR ANDROID EMULATOR THROUGH ADB"
Write-Host "============================================================"

$deviceReady = $false

for ($i = 1; $i -le 180; $i++) {

    Start-Sleep -Seconds 2

    $result = Invoke-SafeCommand `
        -FilePath $adb `
        -Arguments @(
            "devices",
            "-l"
        )

    $devices = $result.Output

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

    if (($i % 10) -eq 0) {

        Write-Host ""
        Write-Host "ADB status at attempt ${i}:"

        $devices | ForEach-Object {
            Write-Host $_
        }

        Write-Host ""
        Write-Host "Emulator process:"

        $running = Get-Process `
            -Name "emulator" `
            -ErrorAction SilentlyContinue

        if ($running) {

            $running |
                Select-Object `
                    Id,
                    ProcessName,
                    CPU |
                Format-Table -AutoSize
        }
        else {

            Write-Host "NO emulator.exe PROCESS FOUND"
        }

        Write-Host ""
        Write-Host "Recent emulator stderr:"

        if (Test-Path $EmulatorStderr) {

            Get-Content `
                -Path $EmulatorStderr `
                -Tail 20 |
                ForEach-Object {
                    Write-Host $_
                }
        }
    }

    Write-Host "Waiting... ${i}/180"
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
    Write-Host "ADB devices:"

    $result = Invoke-SafeCommand `
        -FilePath $adb `
        -Arguments @(
            "devices",
            "-l"
        )

    $result.Output | ForEach-Object {
        Write-Host $_
    }

    Write-Host ""
    Write-Host "ADB version:"

    $result = Invoke-SafeCommand `
        -FilePath $adb `
        -Arguments @(
            "version"
        )

    $result.Output | ForEach-Object {
        Write-Host $_
    }

    Write-Host ""
    Write-Host "Emulator process:"

    Get-Process `
        -Name "emulator" `
        -ErrorAction SilentlyContinue |
        Select-Object `
            Id,
            ProcessName,
            CPU,
            StartTime |
        Format-Table -AutoSize

    Write-Host ""
    Write-Host "============================================================"
    Write-Host " EMULATOR STDOUT - LAST 200 LINES"
    Write-Host "============================================================"

    if (Test-Path $EmulatorStdout) {

        Get-Content `
            -Path $EmulatorStdout `
            -Tail 200 |
            ForEach-Object {
                Write-Host $_
            }
    }

    Write-Host ""
    Write-Host "============================================================"
    Write-Host " EMULATOR STDERR - LAST 300 LINES"
    Write-Host "============================================================"

    if (Test-Path $EmulatorStderr) {

        Get-Content `
            -Path $EmulatorStderr `
            -Tail 300 |
            ForEach-Object {
                Write-Host $_
            }
    }

    throw "Android Emulator did not become available through ADB."
}

# ============================================================
# WAIT FOR ANDROID BOOT
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " WAITING FOR ANDROID BOOT"
Write-Host "============================================================"

$bootCompleted = $false

for ($i = 1; $i -le 180; $i++) {

    Start-Sleep -Seconds 2

    $result = Invoke-SafeCommand `
        -FilePath $adb `
        -Arguments @(
            "-e",
            "shell",
            "getprop",
            "sys.boot_completed"
        )

    $bootValue = ($result.Output -join "`n").Trim()

    if ($bootValue -match "1") {

        $bootCompleted = $true

        Write-Host ""
        Write-Host "Android boot completed."
        break
    }

    if (($i % 10) -eq 0) {

        Write-Host ""
        Write-Host "Boot status at attempt ${i}:"
        Write-Host $bootValue
    }

    Write-Host "Booting... ${i}/180"
}

# ============================================================
# BOOT FAILURE
# ============================================================

if (-not $bootCompleted) {

    Write-Host ""
    Write-Host "============================================================"
    Write-Host " ANDROID BOOT TIMEOUT"
    Write-Host "============================================================"

    Write-Host ""
    Write-Host "ADB devices:"

    $result = Invoke-SafeCommand `
        -FilePath $adb `
        -Arguments @(
            "devices",
            "-l"
        )

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
    Write-Host "============================================================"
    Write-Host " EMULATOR STDERR"
    Write-Host "============================================================"

    if (Test-Path $EmulatorStderr) {

        Get-Content `
            -Path $EmulatorStderr `
            -Tail 300 |
            ForEach-Object {
                Write-Host $_
            }
    }

    throw "Android Emulator connected to ADB but Android did not finish booting."
}

# ============================================================
# WAIT FOR PACKAGE MANAGER
# ============================================================

Write-Host ""
Write-Host "Waiting for Android package manager..."

$packageManagerReady = $false

for ($i = 1; $i -le 90; $i++) {

    Start-Sleep -Seconds 2

    $result = Invoke-SafeCommand `
        -FilePath $adb `
        -Arguments @(
            "-e",
            "shell",
            "pm",
            "path",
            "android"
        )

    if ($result.Output -match "package:") {

        $packageManagerReady = $true

        Write-Host "Android package manager ready."
        break
    }

    Write-Host "Package manager... ${i}/90"
}

if (-not $packageManagerReady) {

    Write-Host ""
    Write-Host "WARNING: package manager did not respond within timeout."
}

# ============================================================
# ANDROID VERSION
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " ANDROID INFORMATION"
Write-Host "============================================================"

Write-Host ""
Write-Host "Android release:"

$result = Invoke-SafeCommand `
    -FilePath $adb `
    -Arguments @(
        "-e",
        "shell",
        "getprop",
        "ro.build.version.release"
    )

$result.Output | ForEach-Object {
    Write-Host $_
}

Write-Host ""
Write-Host "SDK level:"

$result = Invoke-SafeCommand `
    -FilePath $adb `
    -Arguments @(
        "-e",
        "shell",
        "getprop",
        "ro.build.version.sdk"
    )

$result.Output | ForEach-Object {
    Write-Host $_
}

Write-Host ""
Write-Host "CPU ABI:"

$result = Invoke-SafeCommand `
    -FilePath $adb `
    -Arguments @(
        "-e",
        "shell",
        "getprop",
        "ro.product.cpu.abi"
    )

$result.Output | ForEach-Object {
    Write-Host $_
}

Write-Host ""
Write-Host "Device model:"

$result = Invoke-SafeCommand `
    -FilePath $adb `
    -Arguments @(
        "-e",
        "shell",
        "getprop",
        "ro.product.model"
    )

$result.Output | ForEach-Object {
    Write-Host $_
}

# ============================================================
# SCREEN INFORMATION
# ============================================================

Write-Host ""
Write-Host "Display information:"

$result = Invoke-SafeCommand `
    -FilePath $adb `
    -Arguments @(
        "-e",
        "shell",
        "wm",
        "size"
    )

$result.Output | ForEach-Object {
    Write-Host $_
}

# ============================================================
# BROWSER DISPLAY CHECK
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " BROWSER DISPLAY CHECK"
Write-Host "============================================================"

$browserPort = Get-NetTCPConnection `
    -LocalPort 8080 `
    -State Listen `
    -ErrorAction SilentlyContinue

if ($browserPort) {

    Write-Host ""
    Write-Host "Browser port 8080: LISTENING"

}
else {

    Write-Host ""
    Write-Host "Browser port 8080: NOT LISTENING"

    Write-Host ""
    Write-Host "This is not an emulator failure."
    Write-Host "The browser/noVNC service may start in setup-rdp.ps1."
}

# ============================================================
# FINAL ADB STATUS
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " FINAL ADB STATUS"
Write-Host "============================================================"

$result = Invoke-SafeCommand `
    -FilePath $adb `
    -Arguments @(
        "devices",
        "-l"
    )

$result.Output | ForEach-Object {
    Write-Host $_
}

# ============================================================
# FINAL
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
Write-Host "Resolution:"
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
Write-Host "Fullscreen:"
Write-Host "OFF"

Write-Host ""
Write-Host "ADB:"
Write-Host "CONNECTED"

Write-Host ""
Write-Host "Emulator PID:"
Write-Host $emuProcess.Id

Write-Host ""
Write-Host "Browser:"
Write-Host "http://<TAILSCALE-IP>:8080"

Write-Host ""
Write-Host "STDOUT LOG:"
Write-Host $EmulatorStdout

Write-Host ""
Write-Host "STDERR LOG:"
Write-Host $EmulatorStderr

Write-Host ""
Write-Host "============================================================"
Write-Host " EMULATOR SETUP COMPLETE"
Write-Host "============================================================"
