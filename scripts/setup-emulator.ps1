$ErrorActionPreference = "Stop"

$sdk = "C:\Android\android-sdk"
$emulator = Join-Path $sdk "emulator\emulator.exe"
$avd = "Android26"
$grpcPort = 8556

$env:ANDROID_HOME = $sdk
$env:ANDROID_SDK_ROOT = $sdk
$env:PATH = "$sdk\platform-tools;$sdk\emulator;$env:PATH"

Write-Host ""
Write-Host "============================================================"
Write-Host " ANDROID26 + WEBRTC EMULATOR"
Write-Host "============================================================"

if (-not (Test-Path $emulator)) {
    throw "emulator.exe not found: $emulator"
}

# Stop old emulator
Get-Process emulator -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue

Start-Sleep -Seconds 2

Write-Host ""
Write-Host "Starting Android26..."
Write-Host "gRPC: 127.0.0.1:$grpcPort"

$args = @(
    "-avd", $avd,
    "-no-snapshot",
    "-no-boot-anim",
    "-no-audio",
    "-camera-back", "none",
    "-camera-front", "none",
    "-gpu", "swiftshader_indirect",
    "-memory", "2048",
    "-cores", "2",
    "-no-metrics",
    "-grpc", "127.0.0.1:$grpcPort"
)

$p = Start-Process `
    -FilePath $emulator `
    -ArgumentList $args `
    -PassThru

if (-not $p) {
    throw "Failed to start emulator."
}

# Wait for gRPC TCP port
Write-Host ""
Write-Host "Waiting for emulator gRPC..."

$grpcReady = $false

for ($i = 1; $i -le 90; $i++) {

    Start-Sleep -Seconds 2

    if (-not (Get-Process -Id $p.Id -ErrorAction SilentlyContinue)) {
        throw "Android emulator stopped before gRPC became ready."
    }

    try {
        $tcp = Test-NetConnection `
            -ComputerName "127.0.0.1" `
            -Port $grpcPort `
            -WarningAction SilentlyContinue

        if ($tcp.TcpTestSucceeded) {
            $grpcReady = $true
            break
        }
    }
    catch {}

    if (($i % 10) -eq 0) {
        Write-Host "Waiting for gRPC... $i/90"
    }
}

if (-not $grpcReady) {

    Write-Host ""
    Write-Host "============================================================"
    Write-Host " GRPC DID NOT START"
    Write-Host "============================================================"

    Write-Host ""
    Write-Host "Checking emulator process..."

    Get-Process emulator -ErrorAction SilentlyContinue |
        Select-Object Id, CPU, WorkingSet64 |
        Format-Table -AutoSize

    throw "Emulator gRPC port $grpcPort is not listening."
}

Write-Host ""
Write-Host "gRPC READY: 127.0.0.1:$grpcPort"

# Wait for Android boot
Write-Host ""
Write-Host "Waiting for Android boot..."

$booted = $false

for ($i = 1; $i -le 120; $i++) {

    Start-Sleep -Seconds 2

    if (-not (Get-Process -Id $p.Id -ErrorAction SilentlyContinue)) {
        throw "Android emulator stopped during boot."
    }

    $adb = Join-Path $sdk "platform-tools\adb.exe"

    if (Test-Path $adb) {

        $boot = & $adb -s "emulator-5554" shell getprop sys.boot_completed 2>$null

        if (($boot -join "") -match "1") {
            $booted = $true
            break
        }
    }

    if (($i % 10) -eq 0) {
        Write-Host "Android boot... $i/120"
    }
}

if (-not $booted) {
    Write-Host "WARNING: Android boot property was not confirmed."
    Write-Host "Emulator process and gRPC are still running."
}

Write-Host ""
Write-Host "============================================================"
Write-Host " ANDROID26 READY"
Write-Host "============================================================"

Write-Host "PID:       $($p.Id)"
Write-Host "Android:   8.0 / API 26"
Write-Host "ABI:       x86"
Write-Host "gRPC:      127.0.0.1:$grpcPort"
Write-Host "GPU:       SwiftShader"
Write-Host "RAM:       2048 MB"
Write-Host "CPU:       2 cores"
