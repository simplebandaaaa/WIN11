$ErrorActionPreference = "Stop"

# ============================================================
# ANDROID 8.0 / API 26 EMULATOR
# GitHub Actions Windows Runner
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
# SAFE COMMAND
# ============================================================

function Invoke-SafeCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $false)]
        [string[]]$Arguments = @()
    )

    $oldAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    $output = & $FilePath @Arguments 2>&1
    $exitCode = $LASTEXITCODE

    $ErrorActionPreference = $oldAction

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

Write-Host "SDK:"
Write-Host $Sdk

# ============================================================
# SDKMANAGER
# ============================================================

Write-Host ""
Write-Host "[2/12] Locating sdkmanager..."

$sdkmanager = $null

foreach ($candidate in @(
    "$Sdk\cmdline-tools\latest\bin\sdkmanager.bat",
    "$Sdk\cmdline-tools\bin\sdkmanager.bat",
    "$Sdk\tools\bin\sdkmanager.bat"
)) {
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
        throw "Failed installing package: $package"
    }
}

# ============================================================
# ADB
# ============================================================

Write-Host ""
Write-Host "[4/12] Locating ADB..."

$adb = "$Sdk\platform-tools\adb.exe"

if (-not (Test-Path $adb)) {
    throw "adb.exe not found: $adb"
}

Write-Host "ADB:"
Write-Host $adb

# ============================================================
# EMULATOR
# ============================================================

$emulator = "$Sdk\emulator\emulator.exe"

if (-not (Test-Path $emulator)) {
    throw "emulator.exe not found: $emulator"
}

Write-Host "Emulator:"
Write-Host $emulator

# ============================================================
# AVD MANAGER
# ============================================================

Write-Host ""
Write-Host "[5/12] Locating avdmanager..."

$avdmanager = $null

foreach ($candidate in @(
    "$Sdk\cmdline-tools\latest\bin\avdmanager.bat",
    "$Sdk\cmdline-tools\bin\avdmanager.bat",
    "$Sdk\tools\bin\avdmanager.bat"
)) {
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
# AVD DIRECTORY
# ============================================================

New-Item `
    -ItemType Directory `
    -Path $AvdRoot `
    -Force | Out-Null

# ============================================================
# HARDWARE PROFILE
# ============================================================

Write-Host ""
Write-Host "[6/12] Finding hardware profile..."

$result = Invoke-SafeCommand `
    -FilePath $avdmanager `
    -Arguments @(
        "list",
        "device"
    )

$deviceOutput = $result.Output -join "`n"

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

Write-Host "Selected device:"
Write-Host $DeviceName

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

Write-Host ""
Write-Host "Android26 AVD created successfully."

# ============================================================
# VERIFY AVD
# ============================================================

Write-Host ""
Write-Host "Verifying AVD..."

if (-not (Test-Path $AvdDir)) {
    throw "AVD directory missing: $AvdDir"
}

$configFile = "$AvdDir\config.ini"

if (-not (Test-Path $configFile)) {
    throw "AVD config.ini missing."
}

Write-Host "AVD directory:"
Write-Host $AvdDir

# ============================================================
# CONFIGURE AVD
# ============================================================

Write-Host ""
Write-Host "Applying lightweight configuration..."

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
# RESET ADB
# ============================================================

Write-Host ""
Write-Host "[8/12] Resetting ADB..."

$result = Invoke-SafeCommand `
    -FilePath $adb `
    -Arguments @("kill-server")

$result.Output | ForEach-Object {
    Write-Host $_
}

Start-Sleep -Seconds 2

$result = Invoke-SafeCommand `
    -FilePath $adb `
    -Arguments @("start-server")

$result.Output | ForEach-Object {
    Write-Host $_
}

if ($result.ExitCode -ne 0) {
    throw "ADB server failed to start."
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

Remove-Item `
    $EmulatorStdout `
    -Force `
    -ErrorAction SilentlyContinue

Remove-Item `
    $EmulatorStderr `
    -Force `
    -ErrorAction SilentlyContinue

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
    throw "Failed to start Android Emulator process."
}

Write-Host ""
Write-Host "Emulator PID:"
Write-Host $emuProcess.Id

Write-Host ""
Write-Host "Emulator stdout:"
Write-Host $EmulatorStdout

Write-Host ""
Write-Host "Emulator stderr:"
Write-Host $EmulatorStderr

# ============================================================
# PROCESS CHECK
# ============================================================

Write-Host ""
Write-Host "[9/12] Checking emulator process..."

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

    Write-Host "Process not detected... ${i}/30"
}

if (-not $processFound) {

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
            -Tail 150 |
            ForEach-Object {
                Write-Host $_
            }
    }

    throw "Android Emulator process exited early."
}

# ============================================================
# WAIT FOR ADB
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " WAITING FOR ANDROID EMULATOR THROUGH ADB"
Write-Host "============================================================"

$deviceReady = $false

for ($i = 1; $i -le 120; $i++) {

    Start-Sleep -Seconds 2

    $result = Invoke-SafeCommand `
        -FilePath $adb `
        -Arguments @(
            "devices",
            "-l"
        )

    $devices = $result.Output

    # --------------------------------------------------------
    # DIAGNOSTICS EVERY 10 ATTEMPTS
    # --------------------------------------------------------

    if (($i % 10) -eq 0) {

        Write-Host ""
        Write-Host "ADB status at attempt ${i}:"

        $devices | ForEach-Object {
            Write-Host $_
        }

        Write-Host ""
        Write-Host "Emulator process status:"

        $runningEmulators = Get-Process `
            -Name "emulator" `
            -ErrorAction SilentlyContinue

        if ($runningEmulators) {

            $runningEmulators |
                Select-Object `
                    Id,
                    ProcessName,
                    CPU,
                    StartTime |
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
                -Tail 10 |
                ForEach-Object {
                    Write-Host $_
                }
        }
    }

    # --------------------------------------------------------
    # DETECT DEVICE
    # --------------------------------------------------------

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

    Write-Host "Waiting... ${i}/120"
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
        -Arguments @(
            "devices",
            "-l"
        )

    $result.Output | ForEach-Object {
        Write-Host $_
    }

    Write-Host ""
    Write-Host "----- adb get-state -----"

    $result = Invoke-SafeCommand `
        -FilePath $adb `
        -Arguments @(
            "get-state"
        )

    $result.Output | ForEach-Object {
        Write-Host $_
    }

    Write-Host ""
    Write-Host "----- adb version -----"

    $result = Invoke-SafeCommand `
        -FilePath $adb `
        -Arguments @(
            "version"
        )

    $result.Output | ForEach-Object {
        Write-Host $_
    }

    Write-Host ""
    Write-Host "----- emulator processes -----"

    $processes = Get-Process `
        -Name "emulator" `
        -ErrorAction SilentlyContinue

    if ($processes) {

        $processes |
            Select-Object `
                Id,
                ProcessName,
                CPU,
                StartTime |
            Format-Table -AutoSize

    }
    else {

        Write-Host "NO emulator.exe PROCESS FOUND"
    }

    Write-Host ""
    Write-Host "----- adb processes -----"

    $adbProcesses = Get-Process `
        -Name "adb" `
        -ErrorAction SilentlyContinue

    if ($adbProcesses) {

        $adbProcesses |
            Select-Object `
                Id,
                ProcessName,
                CPU,
                StartTime |
            Format-Table -AutoSize

    }
    else {

        Write-Host "NO adb.exe PROCESS FOUND"
    }

    Write-Host ""
    Write-Host "============================================================"
    Write-Host " EMULATOR STDOUT - LAST 150 LINES"
    Write-Host "============================================================"

    if (Test-Path $EmulatorStdout) {

        Get-Content `
            -Path $EmulatorStdout `
            -Tail 150 |
            ForEach-Object {
                Write-Host $_
            }

    }
    else {

        Write-Host "STDOUT log not found."
    }

    Write-Host ""
    Write-Host "============================================================"
    Write-Host " EMULATOR STDERR - LAST 200 LINES"
    Write-Host "============================================================"

    if (Test-Path $EmulatorStderr) {

        Get-Content `
            -Path $EmulatorStderr `
            -Tail 200 |
            ForEach-Object {
                Write-Host $_
            }

    }
    else {

        Write-Host "STDERR log not found."
    }

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
Write-Host " WAITING FOR ANDROID BOOT"
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

    Write-Host "Booting... ${i}/120"
}

# ============================================================
# BOOT FAILURE
# ============================================================

if (-not $booted) {

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
    Write-Host " EMULATOR STDERR - LAST 200 LINES"
    Write-Host "============================================================"

    if (Test-Path $EmulatorStderr) {

        Get-Content `
            -Path $EmulatorStderr `
            -Tail 200 |
            ForEach-Object {
                Write-Host $_
            }
    }

    throw "Android Emulator connected to ADB but Android did not finish booting."
}

# ============================================================
# ANDROID TEST
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

Write-Host ""
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
Write-Host "ADB:"
Write-Host "CONNECTED"

Write-Host ""
Write-Host "Emulator PID:"
Write-Host $emuProcess.Id

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
