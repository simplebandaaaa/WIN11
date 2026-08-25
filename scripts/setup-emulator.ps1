$ErrorActionPreference = "Stop"

Write-Host "=============================================="
Write-Host " Android Emulator Setup"
Write-Host " Android 8.0 / API 26"
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
# 3. INSTALL REQUIRED COMPONENTS
# ============================================================
# IMPORTANT:
# platform-tools is NOT installed.
# ADB is therefore NOT installed.

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
# 6. FIND A HARDWARE DEVICE PROFILE
# ============================================================
# This prevents:
# "Do you wish to create a custom hardware profile?"
#
# We automatically choose a phone profile instead of answering
# the interactive prompt.

Write-Host ""
Write-Host "Finding Android phone hardware profiles..."

$deviceOutput = & $avdmanager list device 2>&1

$deviceOutput | Select-Object -First 30 | ForEach-Object {
    Write-Host $_
}

# Prefer Pixel profile if available.
$deviceName = $null

$pixelMatch = $deviceOutput |
    Where-Object {
        $_ -match "pixel"
    } |
    Select-Object -First 1

if ($pixelMatch) {
    $deviceName = "pixel"
}

# Fallback profiles
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
    throw "No suitable Android phone hardware profile was found."
}

Write-Host ""
Write-Host "Selected hardware profile:"
Write-Host $deviceName

# ============================================================
# 7. AVD DIRECTORY
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
# 8. REMOVE OLD ANDROID26
# ============================================================

Write-Host ""
Write-Host "Checking existing Android26 AVD..."

$existingAvds = & $avdmanager list avd 2>$null

if ($existingAvds -match "Android26") {

    Write-Host "Existing Android26 found."
    Write-Host "Removing old AVD..."

    try {
        & $avdmanager delete avd -n "Android26" 2>$null
    }
    catch {
        Write-Host "Old AVD removal failed. Continuing..."
    }
}
else {
    Write-Host "No previous Android26 AVD found."
}

# Remove leftover files
$oldAvdDirectory = "$avdRoot\Android26.avd"
$oldIni = "$avdRoot\Android26.ini"

if (Test-Path $oldAvdDirectory) {
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
# 9. CREATE AVD
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
# Therefore avdmanager does NOT ask:
# "Do you wish to create a custom hardware profile?"
#
# No stdin / no "no" / no BOM issue.

$arguments = @(
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
Write-Host "Running avdmanager..."

& $avdmanager @arguments

if ($LASTEXITCODE -ne 0) {
    throw "Failed to create Android26 AVD. Exit code: $LASTEXITCODE"
}

Write-Host ""
Write-Host "Android26 AVD created successfully."

# ============================================================
# 10. VERIFY
# ============================================================

Write-Host ""
Write-Host "Verifying AVD..."

$verifyAvds = & $avdmanager list avd 2>&1

$verifyAvds | ForEach-Object {
    Write-Host $_
}

if ($verifyAvds -notmatch "Android26") {
    throw "Android26 AVD was not found after creation."
}

Write-Host ""
Write-Host "AVD verification successful."

# ============================================================
# 11. LIGHTWEIGHT CONFIGURATION
# ============================================================

$config = "$avdRoot\Android26.avd\config.ini"

if (Test-Path $config) {

    Write-Host ""
    Write-Host "Applying lightweight configuration..."

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
        -Path $config `
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
        -Path $config `
        -Value $content `
        -Encoding ASCII
}

# ============================================================
# 12. START EMULATOR
# ============================================================

Write-Host ""
Write-Host "=============================================="
Write-Host " Starting Android Emulator"
Write-Host "=============================================="

$emulatorArguments = @(
    "-avd", "Android26",
    "-no-snapshot",
    "-no-boot-anim",
    "-no-audio",
    "-camera-back", "none",
    "-camera-front", "none",
    "-gpu", "swiftshader_indirect",
    "-memory", "1536",
    "-cores", "2",
    "-no-metrics"
)

$emulatorProcess = Start-Process `
    -FilePath $emulator `
    -ArgumentList $emulatorArguments `
    -WindowStyle Hidden `
    -PassThru

Write-Host ""
Write-Host "Emulator process started."
Write-Host "PID:"
Write-Host $emulatorProcess.Id

# ============================================================
# 13. WAIT FOR PROCESS
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

        Write-Host "Emulator process is running."
        break
    }

    Write-Host "Waiting... $i/60"
}

# ============================================================
# 14. FINAL STATUS
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
    Write-Host "Access:"
    Write-Host "Windows RDP"

}
else {

    Write-Host " EMULATOR DID NOT START"
    Write-Host "=============================================="

    exit 1
}

Write-Host ""
Write-Host "=============================================="
Write-Host " Android Emulator setup completed"
Write-Host "=============================================="
