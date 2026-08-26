$ErrorActionPreference = "Stop"

$sdk = "C:\Android\android-sdk"
$emulator = "$sdk\emulator\emulator.exe"
$avd = "Android26"

$env:ANDROID_HOME = $sdk
$env:ANDROID_SDK_ROOT = $sdk
$env:PATH = "$sdk\platform-tools;$sdk\emulator;$env:PATH"

Write-Host "============================================================"
Write-Host " ANDROID26 + WEBRTC EMULATOR"
Write-Host "============================================================"

if (-not (Test-Path $emulator)) {
    throw "emulator.exe not found"
}

Get-Process emulator -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue

Start-Sleep 2

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

    # Native emulator gRPC endpoint used by the WebRTC gateway
    "-grpc", "127.0.0.1:8556"
)

Write-Host ""
Write-Host "Starting Android26..."
Write-Host "gRPC: 127.0.0.1:8556"

$p = Start-Process `
    -FilePath $emulator `
    -ArgumentList $args `
    -PassThru

for ($i = 1; $i -le 120; $i++) {

    Start-Sleep 2

    if (-not (Get-Process -Id $p.Id -ErrorAction SilentlyContinue)) {
        throw "Android emulator stopped."
    }

    if (($i % 10) -eq 0) {
        Write-Host "Emulator running... $i/120"
    }
}

Write-Host ""
Write-Host "============================================================"
Write-Host " ANDROID26 RUNNING"
Write-Host "============================================================"
Write-Host "PID: $($p.Id)"
Write-Host "gRPC: 127.0.0.1:8556"
