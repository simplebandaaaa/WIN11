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

$sdkmanagerCandidates = @(
    "$Sdk\cmdline-tools\latest\bin\sdkmanager.bat",
    "$Sdk\cmdline-tools\bin\sdkmanager.bat",
    "$Sdk\tools\bin\sdkmanager.bat"
)

$sdkmanager = $null

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
# 3. ACCEPT LICENSES
# ============================================================

Write-Host ""
Write-Host "Accepting Android SDK licenses..."

$licenseText = ""

for ($i = 0; $i -lt 100; $i++) {
    $licenseText += "y`r`n"
}

$psiLicense = New-Object System.Diagnostics.ProcessStartInfo

$psiLicense.FileName = $sdkmanager
$psiLicense.Arguments = "--licenses"
$psiLicense.UseShellExecute = $false
$psiLicense.RedirectStandardInput = $true
$psiLicense.RedirectStandardOutput = $true
$psiLicense.RedirectStandardError = $true
$psiLicense.CreateNoWindow = $true

$licenseProcess = New-Object System.Diagnostics.Process
$licenseProcess.StartInfo = $psiLicense

[void]$licenseProcess.Start()

$licenseProcess.StandardInput.Write($licenseText)
$licenseProcess.StandardInput.Close()

$licenseOut = $licenseProcess.StandardOutput.ReadToEnd()
$licenseErr = $licenseProcess.StandardError.ReadToEnd()

$licenseProcess.WaitForExit()

Write-Host $licenseOut

# ============================================================
# 4. INSTALL REQUIRED COMPONENTS
# ============================================================
# IMPORTANT:
# platform-tools is intentionally NOT installed.
# Therefore ADB is NOT installed.

Write-Host ""
Write-Host "=============================================="
Write-Host " Installing Emulator Components"
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
# 5. FIND EMULATOR
# ============================================================

$emulator = "$Sdk\emulator\emulator.exe"

if (-not (Test-Path $emulator)) {
    throw "emulator.exe was not found."
}

Write-Host ""
Write-Host "Emulator:"
Write-Host $emulator

# ============================================================
# 6. FIND AVDMANAGER
# ============================================================

$avdmanagerCandidates = @(
    "$Sdk\cmdline-tools\latest\bin\avdmanager.bat",
    "$Sdk\cmdline-tools\bin\avdmanager.bat",
    "$Sdk\tools\bin\avdmanager.bat"
)

$avdmanager = $null

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
# 8. CHECK AND REMOVE OLD AVD
# ============================================================

Write-Host ""
Write-Host "Checking existing Android26 AVD..."

$existingAvds = & $avdmanager list avd 2>$null

if ($existingAvds -match "Android26") {

    Write-Host "Existing Android26 found."
    Write-Host "Removing old Android26..."

    try {

        & $avdmanager `
            delete `
            avd `
            -n "Android26" `
            2>$null

    }
    catch {

        Write-Host "Old AVD removal returned an error."
        Write-Host "Continuing anyway..."
    }

}
else {

    Write-Host "No previous Android26 AVD found."
    Write-Host "Fresh AVD will be created."
}

# ============================================================
# 9. REMOVE LEFTOVER FILES
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

# ------------------------------------------------------------
# IMPORTANT:
# Do not pipe a PowerShell array containing "no".
# That can introduce an invisible BOM character:
#
# Error: ﻿no is not a valid reply
#
# Instead start avdmanager directly and send clean ASCII
# "no" through StandardInput.
# ------------------------------------------------------------

$psi = New-Object System.Diagnostics.ProcessStartInfo

$psi.FileName = $avdmanager
$psi.Arguments = "create avd -n Android26 -k `"$systemImage`" --force"
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.CreateNoWindow = $true

$avdProcess = New-Object System.Diagnostics.Process
$avdProcess.StartInfo = $psi

[void]$avdProcess.Start()

# Clean ASCII response
$avdProcess.StandardInput.Write("no")
$avdProcess.StandardInput.Write([Environment]::NewLine)
$avdProcess.StandardInput.Close()

$avdStdOut = $avdProcess.StandardOutput.ReadToEnd()
$avdStdErr = $avdProcess.StandardError.ReadToEnd()

$avdProcess.WaitForExit()

if (-not [string]::IsNullOrWhiteSpace($avdStdOut)) {
    Write-Host $avdStdOut
}

if (-not [string]::IsNullOrWhiteSpace($avdStdErr)) {
    Write-Host $avdStdErr
}

if ($avdProcess.ExitCode -ne 0) {
    throw "Failed to create Android26 AVD. Exit code: $($avdProcess.ExitCode)"
}

Write-Host ""
Write-Host "Android26 AVD creation command completed."

# ============================================================
# 11. VERIFY AVD
# ============================================================

Write-Host ""
Write-Host "Verifying Android26 AVD..."

$verifyAvds = & $avdmanager list avd 2>&1

$verifyAvds | ForEach-Object {
    Write-Host $_
}

if ($verifyAvds -notmatch "Android26") {
    throw "Android26 AVD was not found after creation."
}

Write-Host ""
Write-Host "Android26 AVD verified successfully."

# ============================================================
# 12. CONFIGURE LIGHTWEIGHT AVD
# ============================================================

$config = "$avdRoot\Android26.avd\config.ini"

if (Test-Path $config) {

    Write-Host ""
    Write-Host "=============================================="
    Write-Host " Applying Lightweight Configuration"
    Write-Host "=============================================="

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
# 13. START EMULATOR
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
Write-Host "PID: $($emulatorProcess.Id)"

# ============================================================
# 14. WAIT FOR EMULATOR PROCESS
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
# 15. FINAL STATUS
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
    Write-Host "google_apis / x86"

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

    Write-Host ""
    Write-Host "The emulator process exited unexpectedly."

    exit 1
}

Write-Host ""
Write-Host "=============================================="
Write-Host " Android Emulator setup completed"
Write-Host "=============================================="
