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
# SDK MANAGER
# ============================================================

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

Write-Host ""
Write-Host "SDK Manager:"
Write-Host $sdkmanager

# ============================================================
# INSTALL ANDROID COMPONENTS
# ============================================================

Write-Host ""
Write-Host "=============================================="
Write-Host " Installing Android Components"
Write-Host "=============================================="

foreach ($package in @(
    "platform-tools",
    "emulator",
    "platforms;android-26",
    "system-images;android-26;google_apis;x86"
)) {

    Write-Host ""
    Write-Host "Installing: $package"

    & $sdkmanager $package

    if ($LASTEXITCODE -ne 0) {
        throw "Failed installing $package"
    }
}

# ============================================================
# AVD MANAGER
# ============================================================

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

# ============================================================
# ADB
# ============================================================

$adb = "$Sdk\platform-tools\adb.exe"

if (-not (Test-Path $adb)) {
    throw "adb.exe not found."
}

Write-Host ""
Write-Host "ADB:"
Write-Host $adb

# ============================================================
# EMULATOR
# ============================================================

$emulator = "$Sdk\emulator\emulator.exe"

if (-not (Test-Path $emulator)) {
    throw "emulator.exe not found."
}

Write-Host ""
Write-Host "Emulator:"
Write-Host $emulator

# ============================================================
# HARDWARE PROFILE
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
    throw "No suitable Android hardware profile found."
}

Write-Host ""
Write-Host "Selected hardware profile:"
Write-Host $DeviceName

# ============================================================
# AVD DIRECTORIES
# ============================================================

$AvdRoot = $env:ANDROID_AVD_HOME
$AvdDir = "$AvdRoot\$AvdName.avd"
$AvdIni = "$AvdRoot\$AvdName.ini"

New-Item `
    -ItemType Directory `
    -Path $AvdRoot `
    -Force | Out-Null

# ============================================================
# REMOVE OLD AVD
# ============================================================

Write-Host ""
Write-Host "Checking existing Android26 AVD..."

$existing = & $avdmanager list avd 2>$null

if ($existing -match "Name:\s*$AvdName") {

    Write-Host "Removing old Android26..."

    & $avdmanager delete avd -n $AvdName 2>$null
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
# VERIFY FILES
# ============================================================

if (-not (Test-Path $AvdDir)) {
    throw "Android26 AVD directory missing."
}

$config = "$AvdDir\config.ini"

if (-not (Test-Path $config)) {
    throw "Android26 config.ini missing."
}

Write-Host ""
Write-Host "Android26 AVD verified successfully."

# ============================================================
# LIGHTWEIGHT CONFIG
# ============================================================

$content = Get-Content `
    -Path $config `
    -ErrorAction SilentlyContinue

$settings = @{
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
    $pattern = "^$([regex]::Escape($key))="

    if ($content -match $pattern) {
        $content = $content -replace $pattern, "$key=$value"
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
Write-Host "Lightweight configuration applied."

# ============================================================
# START ADB SERVER FIRST
# ============================================================
# IMPORTANT FIX:
# adb's daemon-start message is normal.
# We explicitly start the server and capture its exit code
# without allowing PowerShell's ErrorActionPreference to abort.

Write-Host ""
Write-Host "=============================================="
Write-Host " Starting ADB Server"
Write-Host "=============================================="

$oldErrorAction = $ErrorActionPreference
$ErrorActionPreference = "Continue"

$adbStartOutput = & $adb start-server 2>&1
$adbStartExit = $LASTEXITCODE

$ErrorActionPreference = $oldErrorAction

$adbStartOutput | ForEach-Object {
    Write-Host $_
}

if ($adbStartExit -ne 0) {
    throw "ADB server failed to start. Exit code: $adbStartExit"
}

Write-Host ""
Write-Host "ADB server started."

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

if (-not $emuProcess) {
    throw "Failed to start emulator."
}

Write-Host ""
Write-Host "Emulator PID:"
Write-Host $emuProcess.Id

# ============================================================
# WAIT FOR EMULATOR DEVICE
# ============================================================

Write-Host ""
Write-Host "Waiting for Android Emulator..."

$deviceReady = $false

for ($i = 1; $i -le 120; $i++) {

    Start-Sleep -Seconds 2

    $oldErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    $devices = & $adb devices 2>&1
    $adbExit = $LASTEXITCODE

    $ErrorActionPreference = $oldErrorAction

    $devices | ForEach-Object {
        if ($_ -match "emulator-") {
            Write-Host $_
        }
    }

    if (
        ($adbExit -eq 0) -and
        ($devices -match "emulator-\d+\s+device")
    ) {

        $deviceReady = $true

        Write-Host ""
        Write-Host "Android Emulator detected."

        break
    }

    Write-Host "Waiting... $i/120"
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

    $oldErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    $boot = & $adb shell getprop sys.boot_completed 2>&1

    $ErrorActionPreference = $oldErrorAction

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

Start-Sleep -Seconds 5

# ============================================================
# INSTALL NODE.JS IF NEEDED
# ============================================================

Write-Host ""
Write-Host "Checking Node.js..."

$node = Get-Command node.exe -ErrorAction SilentlyContinue

if (-not $node) {

    Write-Host "Node.js not found."
    Write-Host "Installing Node.js LTS..."

    $nodeInstaller = "$env:TEMP\node-lts.msi"

    Invoke-WebRequest `
        -Uri "https://nodejs.org/dist/v22.19.0/node-v22.19.0-x64.msi" `
        -OutFile $nodeInstaller `
        -UseBasicParsing

    Start-Process `
        -FilePath "msiexec.exe" `
        -ArgumentList @(
            "/i",
            "`"$nodeInstaller`"",
            "/qn",
            "/norestart"
        ) `
        -Wait

    Remove-Item `
        -Path $nodeInstaller `
        -Force `
        -ErrorAction SilentlyContinue

    $env:Path = "$env:ProgramFiles\nodejs;$env:Path"
}

$node = Get-Command node.exe -ErrorAction SilentlyContinue

if (-not $node) {
    throw "Node.js is unavailable."
}

Write-Host ""
Write-Host "Node.js:"
& node --version

Write-Host ""
Write-Host "npm:"
& npm --version

# ============================================================
# DOWNLOAD WS-SCRCPY-WEB SOURCE
# ============================================================

Write-Host ""
Write-Host "=============================================="
Write-Host " Installing Browser Emulator Bridge"
Write-Host "=============================================="

if (Test-Path $BrowserApp) {

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

$repoZip = "$env:TEMP\ws-scrcpy-web.zip"

Invoke-WebRequest `
    -Uri "https://github.com/bilbospocketses/ws-scrcpy-web/archive/refs/heads/main.zip" `
    -OutFile $repoZip `
    -UseBasicParsing

Expand-Archive `
    -Path $repoZip `
    -DestinationPath $BrowserApp `
    -Force

Remove-Item `
    -Path $repoZip `
    -Force `
    -ErrorAction SilentlyContinue

$sourceDir = Get-ChildItem `
    -Path $BrowserApp `
    -Directory |
    Select-Object -First 1

if (-not $sourceDir) {
    throw "ws-scrcpy-web source directory was not found."
}

$sourcePath = $sourceDir.FullName

Write-Host ""
Write-Host "Source:"
Write-Host $sourcePath

# ============================================================
# INSTALL NPM DEPENDENCIES
# ============================================================

if (Test-Path "$sourcePath\package.json") {

    Write-Host ""
    Write-Host "Installing browser bridge dependencies..."

    Push-Location $sourcePath

    & npm install --omit=dev

    $npmExit = $LASTEXITCODE

    Pop-Location

    if ($npmExit -ne 0) {
        throw "npm install failed."
    }

}
else {
    throw "package.json was not found."
}

# ============================================================
# FIND START SCRIPT
# ============================================================

$packageJson = Get-Content `
    -Path "$sourcePath\package.json" `
    -Raw |
    ConvertFrom-Json

$startCommand = $null

if ($packageJson.scripts.start) {
    $startCommand = $packageJson.scripts.start
}
elseif ($packageJson.scripts.dev) {
    $startCommand = $packageJson.scripts.dev
}
elseif ($packageJson.scripts.serve) {
    $startCommand = $packageJson.scripts.serve
}

if (-not $startCommand) {
    throw "No start/dev/serve script found in ws-scrcpy-web package.json."
}

Write-Host ""
Write-Host "Browser bridge command:"
Write-Host $startCommand

# ============================================================
# START WEB SERVER
# ============================================================

Write-Host ""
Write-Host "=============================================="
Write-Host " Starting Browser Emulator Server"
Write-Host "=============================================="

$serverLog = "$env:TEMP\ws-scrcpy-web.log"

$serverArgs = @(
    "/c",
    "npm",
    "run",
    "start",
    "--",
    "--host",
    "127.0.0.1",
    "--port",
    "$WebPort"
)

$serverProcess = Start-Process `
    -FilePath "cmd.exe" `
    -ArgumentList $serverArgs `
    -WorkingDirectory $sourcePath `
    -WindowStyle Hidden `
    -RedirectStandardOutput $serverLog `
    -RedirectStandardError $serverLog `
    -PassThru

Write-Host ""
Write-Host "Browser server PID:"
Write-Host $serverProcess.Id

# ============================================================
# WAIT FOR LOCALHOST PORT
# ============================================================

Write-Host ""
Write-Host "Waiting for localhost:$WebPort ..."

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

    if (Test-Path $serverLog) {

        $logTail = Get-Content `
            -Path $serverLog `
            -Tail 3 `
            -ErrorAction SilentlyContinue

        $logTail | ForEach-Object {
            Write-Host $_
        }
    }

    Write-Host "Waiting... $i/90"
}

if (-not $webReady) {

    Write-Host ""
    Write-Host "=============================================="
    Write-Host " Browser server failed to start"
    Write-Host "=============================================="

    if (Test-Path $serverLog) {

        Write-Host ""
        Write-Host "Server log:"
        Get-Content $serverLog
    }

    throw "Browser emulator server did not open localhost:$WebPort"
}

# ============================================================
# FIND CHROME / EDGE
# ============================================================

Write-Host ""
Write-Host "Opening Chrome/Edge..."

$browser = $null

foreach ($path in @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
)) {

    if (Test-Path $path) {

        $browser = $path
        break
    }
}

if ($browser) {

    Start-Process `
        -FilePath $browser `
        -ArgumentList @(
            "--new-window",
            "http://localhost:$WebPort"
        )

    Write-Host ""
    Write-Host "Browser opened."

}
else {

    Write-Host ""
    Write-Host "Chrome/Edge executable not found."
    Write-Host ""
    Write-Host "Open manually:"
    Write-Host "http://localhost:$WebPort"
}

# ============================================================
# FINAL
# ============================================================

Write-Host ""
Write-Host "=============================================="
Write-Host " ANDROID BROWSER EMULATOR READY"
Write-Host "=============================================="

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
Write-Host "Target:"
Write-Host "30 FPS / low-data"

Write-Host ""
Write-Host "Controls:"
Write-Host "Touch + Mouse + Keyboard"

Write-Host ""
Write-Host "Fullscreen:"
Write-Host "OFF"

Write-Host ""
Write-Host "Audio:"
Write-Host "OFF"

Write-Host ""
Write-Host "Camera:"
Write-Host "OFF"

Write-Host ""
Write-Host "Browser:"
Write-Host "Chrome / Edge"

Write-Host ""
Write-Host "URL:"
Write-Host "http://localhost:8000"

Write-Host ""
Write-Host "ADB:"
Write-Host "ENABLED"

Write-Host ""
Write-Host "=============================================="
