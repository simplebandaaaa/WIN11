$ErrorActionPreference = "Stop"

Write-Host "=============================================="
Write-Host " Android Emulator Setup"
Write-Host " API 26 / Android 8.0"
Write-Host "=============================================="

# ------------------------------------------------------------
# Android SDK
# ------------------------------------------------------------

$possibleSdkPaths = @(
    "$env:LOCALAPPDATA\Android\Sdk",
    "C:\Android\Sdk",
    "$env:ANDROID_SDK_ROOT"
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
    throw "Android SDK could not be found."
}

$env:ANDROID_HOME = $Sdk
$env:ANDROID_SDK_ROOT = $Sdk

Write-Host ""
Write-Host "Android SDK:"
Write-Host $Sdk

# ------------------------------------------------------------
# Find sdkmanager
# ------------------------------------------------------------

$sdkManagerCandidates = @(
    "$Sdk\cmdline-tools\latest\bin\sdkmanager.bat",
    "$Sdk\cmdline-tools\bin\sdkmanager.bat",
    "$Sdk\tools\bin\sdkmanager.bat"
)

$sdkmanager = $null

foreach ($candidate in $sdkManagerCandidates) {

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

# ------------------------------------------------------------
# Accept licenses
# ------------------------------------------------------------

Write-Host ""
Write-Host "Accepting Android licenses..."

$licenseInput = @()

for ($i = 0; $i -lt 50; $i++) {
    $licenseInput += "y"
}

$licenseInput |
    & $sdkmanager --licenses 2>$null

# ------------------------------------------------------------
# Install ONLY emulator components
# ------------------------------------------------------------
# No ADB / platform-tools are installed here.

Write-Host ""
Write-Host "Installing Android Emulator components..."

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
        Write-Warning "Package installation returned code $LASTEXITCODE"
    }
}

# ------------------------------------------------------------
# Find emulator executable
# ------------------------------------------------------------

$emulator = "$Sdk\emulator\emulator.exe"

if (-not (Test-Path $emulator)) {
    throw "emulator.exe was not found."
}

Write-Host ""
Write-Host "Emulator:"
Write-Host $emulator

# ------------------------------------------------------------
# Find avdmanager
# ------------------------------------------------------------

$avdManagerCandidates = @(
    "$Sdk\cmdline-tools\latest\bin\avdmanager.bat",
    "$Sdk\cmdline-tools\bin\avdmanager.bat",
    "$Sdk\tools\bin\avdmanager.bat"
)

$avdmanager = $null

foreach ($candidate in $avdManagerCandidates) {

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

# ------------------------------------------------------------
# AVD directory
# ------------------------------------------------------------

$avdRoot = "$env:USERPROFILE\.android\avd"

if (-not (Test-Path $avdRoot)) {

    New-Item `
        -ItemType Directory `
        -Path $avdRoot `
        -Force | Out-Null
}

$env:ANDROID_AVD_HOME = $avdRoot

# ------------------------------------------------------------
# Remove old AVD
# ------------------------------------------------------------

Write-Host ""
Write-Host "Removing previous Android26 AVD..."

& $avdmanager `
    delete `
    avd `
    -n "Android26" 2>$null

# ------------------------------------------------------------
# Create new API 26 AVD
# ------------------------------------------------------------

Write-Host ""
Write-Host "Creating Android 8.0 / API 26 AVD..."

"no" |
    & $avdmanager `
        create `
        avd `
        -n "Android26" `
        -k "system-images;android-26;google_apis;x86" `
        --force

if ($LASTEXITCODE -ne 0) {
    throw "Could not create Android26 AVD."
}

# ------------------------------------------------------------
# Configure lightweight emulator
# ------------------------------------------------------------

$config = "$avdRoot\Android26.avd\config.ini"

if (Test-Path $config) {

    Write-Host ""
    Write-Host "Applying lightweight configuration..."

    $settings = @(
        "hw.ramSize=1536"
        "vm.heapSize=256"
        "hw.cpu.ncore=2"
        "hw.gpu.enabled=yes"
        "hw.gpu.mode=swiftshader_indirect"
        "hw.camera.back=none"
        "hw.camera.front=none"
        "disk.dataPartition.size=2048M"
        "showDeviceFrame=no"
        "skin.dynamic=no"
    )

    foreach ($setting in $settings) {
        Add-Content `
            -Path $config `
            -Value $setting
    }
}

# ------------------------------------------------------------
# Start emulator
# ------------------------------------------------------------

Write-Host ""
Write-Host "Starting Android Emulator..."

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

Start-Process `
    -FilePath $emulator `
    -ArgumentList $emulatorArguments `
    -WindowStyle Hidden

Write-Host ""
Write-Host "=============================================="
Write-Host " ANDROID EMULATOR STARTED"
Write-Host "=============================================="

Write-Host ""
Write-Host "AVD:"
Write-Host "Android26"

Write-Host ""
Write-Host "Android:"
Write-Host "Android 8.0 / API 26"

Write-Host ""
Write-Host "CPU:"
Write-Host "2 cores"

Write-Host ""
Write-Host "RAM:"
Write-Host "1536 MB"

Write-Host ""
Write-Host "ADB:"
Write-Host "NOT INSTALLED"

Write-Host ""
Write-Host "The emulator GUI will be available through RDP."

# ------------------------------------------------------------
# Give emulator time to start
# ------------------------------------------------------------

Write-Host ""
Write-Host "Waiting for emulator window..."

Start-Sleep -Seconds 30

# ------------------------------------------------------------
# Check emulator process
# ------------------------------------------------------------

$process = Get-Process `
    -Name "emulator" `
    -ErrorAction SilentlyContinue

if ($process) {

    Write-Host ""
    Write-Host "Emulator process is running."

}
else {

    Write-Warning "Emulator process was not detected."
}

Write-Host ""
Write-Host "Android Emulator setup finished.".
