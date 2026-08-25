$ErrorActionPreference = "Stop"

Write-Host "=============================================="
Write-Host " Android Emulator Setup"
Write-Host " Android 8.0 / API 26"
Write-Host " Google APIs / x86"
Write-Host " ADB DISABLED"
Write-Host "=============================================="

# ============================================================
# 1. FIND ANDROID SDK
# ============================================================

$possibleSdkPaths = @(
    $env:ANDROID_SDK_ROOT,
    $env:ANDROID_HOME,
    "C:\Android\android-sdk",
    "C:\Android\Sdk",
    "$env:LOCALAPPDATA\Android\Sdk"
)

$Sdk = $null

foreach ($path in $possibleSdkPaths) {

    if (-not [string]::IsNullOrWhiteSpace($path)) {

        if (Test-Path $path) {
            $Sdk = $path
            break
        }
    }
}

if (-not $Sdk) {
    throw "Android SDK was not found."
}

$env:ANDROID_HOME = $Sdk
$env:ANDROID_SDK_ROOT = $Sdk

Write-Host ""
Write-Host "Android SDK:"
Write-Host $Sdk

# ============================================================
# 2. FIND SDKMANAGER
# ============================================================

$sdkmanager = $null

$sdkmanagerCandidates = @(
    "$Sdk\cmdline-tools\latest\bin\sdkmanager.bat",
    "$Sdk\cmdline-tools\bin\sdkmanager.bat",
    "$Sdk\tools\bin\sdkmanager.bat"
)

foreach ($candidate in $sdkmanagerCandidates) {

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
    throw "sdkmanager.bat was not found."
}

Write-Host ""
Write-Host "SDK Manager:"
Write-Host $sdkmanager

# ============================================================
# 3. INSTALL REQUIRED ANDROID COMPONENTS
# ============================================================
# platform-tools intentionally NOT installed.
# Therefore ADB is NOT installed by this script.

Write-Host ""
Write-Host "=============================================="
Write-Host " Installing Android Components"
Write-Host "=============================================="

$packages = @(
    "emulator",
    "platforms;android-26",
    "system-images;android-26;google_apis;x86"
)

foreach ($package in $packages) {

    Write-Host ""
    Write-Host "Installing:"
    Write-Host $package

    & $sdkmanager $package

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install package: $package"
    }
}

# ============================================================
# 4. FIND EMULATOR
# ============================================================

$emulator = "$Sdk\emulator\emulator.exe"

if (-not (Test-Path $emulator)) {
    throw "emulator.exe was not found."
}

Write-Host ""
Write-Host "Emulator:"
Write-Host $emulator

# ============================================================
# 5. FIND AVDMANAGER
# ============================================================

$avdmanager = $null

$avdmanagerCandidates = @(
    "$Sdk\cmdline-tools\latest\bin\avdmanager.bat",
    "$Sdk\cmdline-tools\bin\avdmanager.bat",
    "$Sdk\tools\bin\avdmanager.bat"
)

foreach ($candidate in $avdmanagerCandidates) {

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
    throw "avdmanager.bat was not found."
}

Write-Host ""
Write-Host "AVD Manager:"
Write-Host $avdmanager

# ============================================================
# 6. AVD DIRECTORY
# ============================================================

$androidHome = "$env:USERPROFILE\.android"
$avdRoot = "$androidHome\avd"

if (-not (Test-Path $androidHome)) {

    New-Item `
        -ItemType Directory `
        -Path $androidHome `
        -Force | Out-Null
}

if (-not (Test-Path $avdRoot)) {

    New-Item `
        -ItemType Directory `
        -Path $avdRoot `
        -Force | Out-Null
}

$env:ANDROID_AVD_HOME = $avdRoot

Write-Host ""
Write-Host "AVD directory:"
Write-Host $avdRoot

# ============================================================
# 7. FIND HARDWARE PROFILE
# ============================================================

Write-Host ""
Write-Host "Finding Android hardware profiles..."

$deviceOutput = & $avdmanager list device 2>&1

$deviceName = $null

# Prefer Pixel
$pixelLine = $deviceOutput |
    Where-Object {
        $_ -match "pixel"
    } |
    Select-Object -First 1

if ($pixelLine) {
    $deviceName = "pixel"
}

# Fallback
if (-not $deviceName) {

    $fallbackProfiles = @(
        "Nexus 5",
        "Nexus 5X",
        "Nexus 6P",
        "Nexus 7"
    )

    foreach ($profile in $fallbackProfiles) {

        if ($deviceOutput -match [regex]::Escape($profile)) {

            $deviceName = $profile
            break
        }
    }
}

if (-not $deviceName) {
    throw "No suitable Android hardware profile was found."
}

Write-Host ""
Write-Host "Selected hardware profile:"
Write-Host $deviceName

# ============================================================
# 8. REMOVE OLD AVD
# ============================================================

Write-Host ""
Write-Host "Checking existing Android26 AVD..."

$existingAvds = & $avdmanager list avd 2>$null

if ($existingAvds -match "Name:\s*Android26") {

    Write-Host "Existing Android26 found."
    Write-Host "Removing old AVD..."

    try {

        & $avdmanager `
            delete `
            avd `
            -n "Android26" `
            2>$null

    }
    catch {

        Write-Host "Old AVD removal returned an error."
        Write-Host "Continuing..."
    }

}
else {

    Write-Host "No previous Android26 AVD found."
}

# ============================================================
# 9. REMOVE LEFTOVER AVD FILES
# ============================================================

$oldAvdDirectory = "$avdRoot\Android26.avd"
$oldIni = "$avdRoot\Android26.ini"

if (Test-Path $oldAvdDirectory) {

    Write-Host ""
    Write-Host "Removing leftover AVD directory..."

    Remove-Item `
        -Path $oldAvdDirectory `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue
}

if (Test-Path $oldIni) {

    Remove-Item `
        -Path $oldIni `
        -Force `
        -ErrorAction SilentlyContinue
}

# ============================================================
# 10. CREATE AVD
# ============================================================

Write-Host ""
Write-Host "=============================================="
Write-Host " Creating Android26 AVD"
Write-Host "=============================================="

$systemImage = "system-images;android-26;google_apis;x86"

Write-Host ""
Write-Host "System image:"
Write-Host $systemImage

Write-Host ""
Write-Host "Hardware profile:"
Write-Host $deviceName

# IMPORTANT:
# --device supplies the hardware profile.
# This prevents avdmanager from asking:
# "Do you wish to create a custom hardware profile?"
#
# No "no" is piped into avdmanager.

$createArguments = @(
    "create",
    "avd",
    "-n",
    "Android26",
    "-k",
    $systemImage,
    "-d",
    $deviceName,
    "--force"
)

Write-Host ""
Write-Host "Creating AVD..."

& $avdmanager @createArguments

if ($LASTEXITCODE -ne 0) {
    throw "Failed to create Android26 AVD. Exit code: $LASTEXITCODE"
}

Write-Host ""
Write-Host "Android26 AVD created successfully."

# ============================================================
# 11. VERIFY AVD BY FILES
# ============================================================
# We do NOT rely only on text matching from:
# avdmanager list avd
#
# The previous script failed here even though Android26
# actually existed. We therefore verify the actual AVD files.

Write-Host ""
Write-Host "=============================================="
Write-Host " Verifying Android26 AVD"
Write-Host "=============================================="

$avdDirectory = "$avdRoot\Android26.avd"
$avdConfig = "$avdDirectory\config.ini"
$avdIni = "$avdRoot\Android26.ini"

if (Test-Path $avdDirectory) {

    Write-Host ""
    Write-Host "Android26 AVD directory found:"
    Write-Host $avdDirectory

}
else {

    throw "Android26 AVD directory was not created."
}

if (Test-Path $avdConfig) {

    Write-Host ""
    Write-Host "Android26 config.ini found."

}
else {

    throw "Android26 config.ini was not found."
}

if (Test-Path $avdIni) {

    Write-Host ""
    Write-Host "Android26.ini found."

}
else {

    Write-Host ""
    Write-Host "Android26.ini not found."
    Write-Host "Continuing because the AVD directory and config exist."
}

Write-Host ""
Write-Host "Android26 AVD verified successfully."

# ============================================================
# 12. SHOW AVD INFORMATION
# ============================================================

Write-Host ""
Write-Host "AVD information:"

$verifyOutput = & $avdmanager list avd 2>&1

$verifyOutput | ForEach-Object {
    Write-Host $_
}

# ============================================================
# 13. LIGHTWEIGHT CONFIGURATION
# ============================================================

Write-Host ""
Write-Host "=============================================="
Write-Host " Applying Lightweight Configuration"
Write-Host "=============================================="

if (Test-Path $avdConfig) {

    $settings = @{
        "hw.ramSize" = "1536"
        "vm.heapSize" = "256"
        "hw.cpu.ncore" = "2"
        "hw.gpu.enabled" = "yes"
        "hw.gpu.mode" = "swiftshader_indirect"
        "hw.camera.back" = "none"
        "hw.camera.front" = "none"
        "disk.dataPartition.size" = "2048M"
        "showDeviceFrame" = "no"
        "skin.dynamic" = "no"
        "fastboot.forceColdBoot" = "yes"
    }

    $content = Get-Content `
        -Path $avdConfig `
        -ErrorAction SilentlyContinue

    foreach ($key in $settings.Keys) {

        $value = $settings[$key]

        $pattern = "^$([regex]::Escape($key))="

        if ($content -match $pattern) {

            $content = $content -replace `
                $pattern, `
                "$key=$value"

        }
        else {

            $content += "$key=$value"
        }
    }

    Set-Content `
        -Path $avdConfig `
        -Value $content `
        -Encoding ASCII

    Write-Host ""
    Write-Host "Lightweight configuration applied."

}
else {

    throw "Cannot configure AVD because config.ini is missing."
}

# ============================================================
# 14. VERIFY EMULATOR EXECUTABLE
# ============================================================

if (-not (Test-Path $emulator)) {
    throw "Emulator executable disappeared or is unavailable."
}

# ============================================================
# 15. START EMULATOR
# ============================================================

Write-Host ""
Write-Host "=============================================="
Write-Host " Starting Android Emulator"
Write-Host "=============================================="

$emulatorArguments = @(
    "-avd",
    "Android26",
    "-no-snapshot",
    "-no-boot-anim",
    "-no-audio",
    "-camera-back",
    "none",
    "-camera-front",
    "none",
    "-gpu",
    "swiftshader_indirect",
    "-memory",
    "1536",
    "-cores",
    "2",
    "-no-metrics"
)

Write-Host ""
Write-Host "Launching emulator..."

$emulatorProcess = Start-Process `
    -FilePath $emulator `
    -ArgumentList $emulatorArguments `
    -WindowStyle Hidden `
    -PassThru

if (-not $emulatorProcess) {
    throw "Failed to start emulator process."
}

Write-Host ""
Write-Host "Emulator process started."
Write-Host "PID:"
Write-Host $emulatorProcess.Id

# ============================================================
# 16. WAIT FOR EMULATOR PROCESS
# ============================================================

Write-Host ""
Write-Host "Waiting for emulator process..."

$running = $false

for ($i = 1; $i -le 60; $i++) {

    Start-Sleep -Seconds 2

    $process = Get-Process `
        -Id $emulatorProcess.Id `
        -ErrorAction SilentlyContinue

    if ($process) {

        $running = $true

        Write-Host ""
        Write-Host "Emulator process is running."
        break
    }

    Write-Host "Waiting... $i/60"
}

# ============================================================
# 17. FINAL STATUS
# ============================================================

Write-Host ""
Write-Host "=============================================="

if ($running) {

    Write-Host " ANDROID EMULATOR READY"
    Write-Host "=============================================="

    Write-Host ""
    Write-Host "AVD:"
    Write-Host "Android26"

    Write-Host ""
    Write-Host "Android:"
    Write-Host "Android 8.0 / API 26"

    Write-Host ""
    Write-Host "System image:"
    Write-Host "Google APIs / x86"

    Write-Host ""
    Write-Host "Hardware:"
    Write-Host $deviceName

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
    Write-Host "ADB:"
    Write-Host "NOT INSTALLED"

    Write-Host ""
    Write-Host "RDP:"
    Write-Host "Windows RDP"

}
else {

    Write-Host ""
    Write-Host "=============================================="
    Write-Host " EMULATOR DID NOT START"
    Write-Host "=============================================="

    throw "Android emulator process exited before becoming available."
}

Write-Host ""
Write-Host "=============================================="
Write-Host " Android Emulator setup completed"
Write-Host "=============================================="
