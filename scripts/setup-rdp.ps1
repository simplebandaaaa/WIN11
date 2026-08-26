$ErrorActionPreference = "Stop"

$gatewayPort = 8080
$grpcPort = 8556

Write-Host ""
Write-Host "============================================================"
Write-Host " ANDROID26 WEBRTC STARTUP"
Write-Host "============================================================"

# ------------------------------------------------------------
# Check emulator
# ------------------------------------------------------------

$emu = Get-Process emulator -ErrorAction SilentlyContinue

if (-not $emu) {
    throw "Android26 emulator is not running."
}

Write-Host "Emulator: RUNNING"
Write-Host "PID: $($emu[0].Id)"

# ------------------------------------------------------------
# Check gRPC
# ------------------------------------------------------------

Write-Host ""
Write-Host "Checking emulator gRPC..."

$grpc = Test-NetConnection `
    -ComputerName "127.0.0.1" `
    -Port $grpcPort `
    -WarningAction SilentlyContinue

if (-not $grpc.TcpTestSucceeded) {

    Write-Host ""
    Write-Host "WARNING: gRPC $grpcPort is not listening."
    Write-Host "WebRTC gateway cannot connect to the emulator yet."

}
else {

    Write-Host "gRPC: READY on 127.0.0.1:$grpcPort"
}

# ------------------------------------------------------------
# Windows-safe mode
# ------------------------------------------------------------

Write-Host ""
Write-Host "============================================================"
Write-Host " WINDOWS RDP MODE"
Write-Host "============================================================"

Write-Host ""
Write-Host "Windows RDP/Tailscale is kept unchanged."
Write-Host ""
Write-Host "The official Google emulator WebRTC gateway is not"
Write-Host "being falsely started as a native Windows executable."
Write-Host ""

# ------------------------------------------------------------
# Do NOT throw here.
# The RDP workflow must remain alive.
# ------------------------------------------------------------

Write-Host "WebRTC gateway: NOT STARTED"
Write-Host ""
Write-Host "Android emulator remains running."
Write-Host "RDP remains available."
Write-Host "Tailscale remains available."

# ------------------------------------------------------------
# Keep workflow alive
# ------------------------------------------------------------

Write-Host ""
Write-Host "============================================================"
Write-Host " ANDROID26 STATUS"
Write-Host "============================================================"

Write-Host "Emulator PID : $($emu[0].Id)"
Write-Host "gRPC         : 127.0.0.1:$grpcPort"
Write-Host "RDP          : unchanged"
Write-Host "Tailscale    : unchanged"

Write-Host ""
Write-Host "No unsupported Windows WebRTC gateway was launched."
