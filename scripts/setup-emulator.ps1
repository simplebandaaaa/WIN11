$ErrorActionPreference = "Stop"

Write-Host "=============================================="
Write-Host " Android Emulator + Browser Setup"
Write-Host "=============================================="

# ============================================================
# VARIABLES
# ============================================================

$Sdk = "C:\Android\android-sdk"

$env:ANDROID_HOME = $Sdk
$env:ANDROID_SDK_ROOT = $Sdk

$env:ANDROID_AVD_HOME = "$env:USERPROFILE\.android\avd"

$AvdName = "Android26"

$SystemImage = "system-images;android-26;google_apis;x86"

$WebPort = 8000

$BrowserApp = "$env:USERPROFILE\ws-scrcpy-web"

# ============================================================
# CREATE SDK DIRECTORY
# ============================================================

if (-not (Test-Path $Sdk)) {

    New-Item `
        -ItemType Directory `
        -Path $Sdk `
        -Force | Out-Null
}

# ============================================================
# FIND SDKMANAGER
# ============================================================

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

Write-Host ""
Write-Host "SDK Manager:"
Write-Host $sdkmanager

# ============================================================
# INSTALL SDK COMPONENTS
# ============================================================
# IMPORTANT:
# platform-tools is now intentionally installed because
# browser-based emulator control requires ADB.

Write-Host ""
Write-Host "=============================================="
Write-Host " Installing Android Components"
Write-Host "=============================================="

$packages = @(
    "platform-tools",
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
        throw "Failed installing $package"
    }
}

# ============================================================
# ACCEPT LICENSES
# ============================================================

Write-Host ""
Write-Host "Accepting Android SDK licenses..."

$yes = ("y`n" * 30)

$yes |
    & $sdkmanager --licenses |
    Out-Host

# ============================================================
# LOCATE AVD MANAGER
# ============================================================

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

Write-Host ""
Write-Host "AVD Manager:"
Write-Host $avdmanager

# ============================================================
# FIND HARDWARE PROFILE
# ============================================================

Write-Host ""
Write-Host "Finding hardware profile..."

$deviceOutput = & $avdmanager list device 2>&1

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
    throw "No suitable Android phone hardware profile found."
}

Write-Host ""
Write-Host "Selected:"
Write-Host $DeviceName

# ============================================================
# AVD DIRECTORY
# ============================================================

$AvdRoot = $env:ANDROID_AVD_HOME

if (-not (Test-Path $AvdRoot)) {

    New-Item `
        -ItemType Directory `
        -Path $AvdRoot `
        -Force | Out-Null
}

$AvdDir = "$AvdRoot\$AvdName.avd"

$AvdIni = "$AvdRoot\$AvdName.ini"

# ============================================================
# REMOVE OLD AVD
# ============================================================

Write-Host ""
Write-Host "Checking existing Android26..."

$existing = & $avdmanager list avd 2>$null

if ($existing -match "Name:\s*$AvdName") {

    Write-Host "Removing old Android26..."

    & $avdmanager `
        delete `
        avd `
        -n $AvdName `
        2>$null
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
Write-Host "=============================================="
Write-Host " Creating Android26 AVD"
Write-Host "=============================================="

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

& $avdmanager @createArgs

if ($LASTEXITCODE -ne 0) {
    throw "Android26 AVD creation failed."
}

Write-Host ""
Write-Host "Android26 AVD created successfully."

# ============================================================
# VERIFY BY ACTUAL FILES
# ============================================================

Write-Host ""
Write-Host "Verifying AVD..."

if (-not (Test-Path $AvdDir)) {
    throw "Android26 AVD directory missing."
}

if (-not (Test-Path "$AvdDir\config.ini")) {
    throw "Android26 config.ini missing."
}

Write-Host ""
Write-Host "Android26 AVD verified successfully."

# ============================================================
# CONFIGURE AVD
# ============================================================

$config = "$AvdDir\config.ini"

$content = Get-Content `
    -Path $config `
    -ErrorAction SilentlyContinue

$settings = @{
    "hw.ramSize"                  = "1536"
    "vm.heapSize"                 = "256"
    "hw.cpu.ncore"                = "2"
    "hw.gpu.enabled"              = "yes"
    "hw.gpu.mode"                 = "swiftshader_indirect"
    "hw.camera.back"              = "none"
    "hw.camera.front"             = "none"
    "showDeviceFrame"             = "no"
    "skin.dynamic"                = "no"
    "fastboot.forceColdBoot"      = "yes"
    "disk.dataPartition.size"     = "2048M"
    "hw.lcd.width"                = "600"
    "hw.lcd.height"               = "960"
    "hw.lcd.density"              = "240"
}

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

Write-Host ""
Write-Host "600p-class emulator configuration applied."

# ============================================================
# FIND EMULATOR
# ============================================================

$emulator = "$Sdk\emulator\emulator.exe"

if (-not (Test-Path $emulator)) {
    throw "emulator.exe not found."
}

# ============================================================
# FIND ADB
# ============================================================

$adb = "$Sdk\platform-tools\adb.exe"

if (-not (Test-Path $adb)) {
    throw "adb.exe not found."
}

Write-Host ""
Write-Host "ADB:"
Write-Host $adb

# ============================================================
# START EMULATOR
# ============================================================

Write-Host ""
Write-Host "=============================================="
Write-Host " Starting Android Emulator"
Write-Host "=============================================="

$emuArgs = @(
    "-avd",
    $AvdName,
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

$emuProcess = Start-Process `
    -FilePath $emulator `
    -ArgumentList $emuArgs `
    -WindowStyle Normal `
    -PassThru

Write-Host ""
Write-Host "Emulator PID:"
Write-Host $emuProcess.Id

# ============================================================
# WAIT FOR ADB DEVICE
# ============================================================

Write-Host ""
Write-Host "Waiting for Android Emulator..."

$deviceReady = $false

for ($i = 1; $i -le 120; $i++) {

    Start-Sleep -Seconds 2

    $devices = & $adb devices 2>$null

    if ($devices -match "emulator-\d+\s+device") {

        $deviceReady = $true

        Write-Host ""
        Write-Host "Android Emulator detected."

        break
    }

    Write-Host "Waiting for emulator... $i/120"
}

if (-not $deviceReady) {
    throw "Android Emulator did not become available through ADB."
}

# ============================================================
# WAIT FOR ANDROID BOOT
# ============================================================

Write-Host ""
Write-Host "Waiting for Android boot..."

$booted = $false

for ($i = 1; $i -le 120; $i++) {

    Start-Sleep -Seconds 2

    $boot = & $adb shell getprop sys.boot_completed 2>$null

    if ($boot -match "1") {

        $booted = $true

        Write-Host ""
        Write-Host "Android boot completed."

        break
    }

    Write-Host "Booting... $i/120"
}

if (-not $booted) {
    throw "Android did not finish booting."
}

# ============================================================
# WAIT FOR UI
# ============================================================

Start-Sleep -Seconds 5

# ============================================================
# DOWNLOAD WS-SCRCPY-WEB
# ============================================================

Write-Host ""
Write-Host "=============================================="
Write-Host " Installing Browser Emulator"
Write-Host "=============================================="

if (Test-Path $BrowserApp) {

    Write-Host "Removing previous ws-scrcpy-web..."

    Remove-Item `
        -Path $BrowserApp `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue
}

New-Item `
    -ItemType Directory `
    -Path $BrowserApp `
    -Force | Out-Null

$apiUrl = "https://api.github.com/repos/bilbospocketses/ws-scrcpy-web/releases/latest"

Write-Host ""
Write-Host "Checking latest ws-scrcpy-web release..."

$headers = @{
    "User-Agent" = "GitHub-Actions-Windows-Android-Emulator"
    "Accept" = "application/vnd.github+json"
}

$release = Invoke-RestMethod `
    -Uri $apiUrl `
    -Headers $headers `
    -Method Get

if (-not $release.assets) {
    throw "No ws-scrcpy-web release assets found."
}

# Prefer Windows portable ZIP.
$asset = $release.assets |
    Where-Object {
        $_.name -match "(?i)windows|win" -and
        $_.name -match "(?i)portable|zip" -and
        $_.name -match "(?i)\.zip$"
    } |
    Select-Object -First 1

# Fallback to any Windows ZIP.
if (-not $asset) {

    $asset = $release.assets |
        Where-Object {
            $_.name -match "(?i)win" -and
            $_.name -match "(?i)\.zip$"
        } |
        Select-Object -First 1
}

if (-not $asset) {

    $assetNames = ($release.assets |
        Select-Object -ExpandProperty name) -join ", "

    throw "Windows portable ZIP was not found. Assets: $assetNames"
}

Write-Host ""
Write-Host "Selected browser package:"
Write-Host $asset.name

$zipFile = "$env:TEMP\ws-scrcpy-web.zip"

Invoke-WebRequest `
    -Uri $asset.browser_download_url `
    -OutFile $zipFile `
    -UseBasicParsing

Write-Host ""
Write-Host "Extracting browser package..."

Expand-Archive `
    -Path $zipFile `
    -DestinationPath $BrowserApp `
    -Force

Remove-Item `
    -Path $zipFile `
    -Force `
    -ErrorAction SilentlyContinue

# ============================================================
# FIND START.CMD
# ============================================================

$startCmd = Get-ChildItem `
    -Path $BrowserApp `
    -Filter "start.cmd" `
    -Recurse `
    -ErrorAction SilentlyContinue |
    Select-Object -First 1

if (-not $startCmd) {
    throw "ws-scrcpy-web start.cmd was not found after extraction."
}

Write-Host ""
Write-Host "Browser server launcher:"
Write-Host $startCmd.FullName

# ============================================================
# START BROWSER SERVER
# ============================================================

Write-Host ""
Write-Host "Starting ws-scrcpy-web..."

$env:WS_SCRCPY_PORT = "$WebPort"

# Start server from its own directory.
$serverProcess = Start-Process `
    -FilePath $startCmd.FullName `
    -WorkingDirectory $startCmd.DirectoryName `
    -WindowStyle Hidden `
    -PassThru

Write-Host ""
Write-Host "Browser server PID:"
Write-Host $serverProcess.Id

# ============================================================
# WAIT FOR LOCALHOST:8000
# ============================================================

Write-Host ""
Write-Host "Waiting for browser server..."

$webReady = $false

for ($i = 1; $i -le 90; $i++) {

    Start-Sleep -Seconds 2

    try {

        $tcp = Test-NetConnection `
            -ComputerName "127.0.0.1" `
            -Port $WebPort `
            -WarningAction SilentlyContinue

        if ($tcp.TcpTestSucceeded) {

            $webReady = $true
            break
        }

    }
    catch {
    }

    Write-Host "Waiting for localhost:$WebPort ... $i/90"
}

if (-not $webReady) {

    Write-Host ""
    Write-Host "Browser server did not open port $WebPort."

    throw "ws-scrcpy-web failed to start."
}

# ============================================================
# OPEN CHROME
# ============================================================

Write-Host ""
Write-Host "Opening Chrome/Edge..."

$chromePaths = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
)

$browser = $null

foreach ($path in $chromePaths) {

    if (Test-Path $path) {

        $browser = $path
        break
    }
}

if (-not $browser) {

    $edgePaths = @(
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
    )

    foreach ($path in $edgePaths) {

        if (Test-Path $path) {

            $browser = $path
            break
        }
    }
}

if ($browser) {

    Start-Process `
        -FilePath $browser `
        -ArgumentList "http://localhost:$WebPort"

    Write-Host ""
    Write-Host "Browser opened."

}
else {

    Write-Host ""
    Write-Host "Chrome/Edge executable was not found."
    Write-Host "Open this manually:"
    Write-Host "http://localhost:$WebPort"
}

# ============================================================
# FINAL STATUS
# ============================================================

Write-Host ""
Write-Host "=============================================="
Write-Host " ANDROID BROWSER EMULATOR READY"
Write-Host "=============================================="

Write-Host ""
Write-Host "Android:"
Write-Host "Android 8.0 / API 26"

Write-Host ""
Write-Host "ABI:"
Write-Host "x86"

Write-Host ""
Write-Host "Resolution:"
Write-Host "600p-class"

Write-Host ""
Write-Host "Target:"
Write-Host "30 FPS / low-data"

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
Write-Host "Control:"
Write-Host "Touch + Mouse + Keyboard"

Write-Host ""
Write-Host "Browser:"
Write-Host "Chrome / Edge"

Write-Host ""
Write-Host "URL:"
Write-Host "http://localhost:8000"

Write-Host ""
Write-Host "ADB:"
Write-Host "ENABLED for browser bridge"

Write-Host ""
Write-Host "=============================================="
