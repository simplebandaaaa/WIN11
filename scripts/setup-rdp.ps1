$ErrorActionPreference = "Stop"

$sdk = "C:\Android\android-sdk"
$emulator = "$sdk\emulator\emulator.exe"
$avd = "Android26"

$grpcHost = "127.0.0.1"
$grpcPort = 8556

$env:ANDROID_HOME = $sdk
$env:ANDROID_SDK_ROOT = $sdk
$env:PATH = "$sdk\platform-tools;$sdk\emulator;$env:PATH"

Write-Host ""
Write-Host "============================================================"
Write-Host " ANDROID26 WEBRTC STARTUP"
Write-Host "============================================================"

if (-not (Test-Path $emulator)) {
    throw "emulator.exe not found: $emulator"
}

# ============================================================
# START EMULATOR IF NOT RUNNING
# ============================================================

$emu = Get-Process -Name emulator -ErrorAction SilentlyContinue

if (-not $emu) {

    Write-Host ""
    Write-Host "Android26 is not running."
    Write-Host "Starting emulator..."

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
        "-grpc", "$grpcHost`:$grpcPort"
    )

    $emuProcess = Start-Process `
        -FilePath $emulator `
        -ArgumentList $args `
        -PassThru

    if (-not $emuProcess) {
        throw "Failed to start Android26."
    }

    Write-Host "Emulator PID: $($emuProcess.Id)"

}
else {

    $emuProcess = $emu[0]

    Write-Host ""
    Write-Host "Android26 already running."
    Write-Host "PID: $($emuProcess.Id)"
}

# ============================================================
# WAIT FOR EMULATOR PROCESS
# ============================================================

Write-Host ""
Write-Host "Waiting for emulator process..."

$processReady = $false

for ($i = 1; $i -le 90; $i++) {

    Start-Sleep -Seconds 2

    if (Get-Process -Id $emuProcess.Id -ErrorAction SilentlyContinue) {

        $processReady = $true

        if (($i % 5) -eq 0) {
            Write-Host "Emulator process running... $i/90"
        }

        # Don't wait the entire 3 minutes once process exists.
        if ($i -ge 5) {
            break
        }

    }
    else {
        throw "Android26 emulator stopped during startup."
    }
}

if (-not $processReady) {
    throw "Android26 emulator process did not start."
}

# ============================================================
# WAIT FOR GRPC
# ============================================================

Write-Host ""
Write-Host "Waiting for gRPC $grpcHost`:$grpcPort..."

$grpcReady = $false

for ($i = 1; $i -le 90; $i++) {

    Start-Sleep -Seconds 2

    try {

        $test = Test-NetConnection `
            -ComputerName $grpcHost `
            -Port $grpcPort `
            -WarningAction SilentlyContinue

        if ($test.TcpTestSucceeded) {

            $grpcReady = $true
            break
        }

    }
    catch {
        # Keep waiting.
    }

    if (($i % 10) -eq 0) {
        Write-Host "Waiting for gRPC... $i/90"
    }

    if (-not (Get-Process -Id $emuProcess.Id -ErrorAction SilentlyContinue)) {
        throw "Android26 stopped before gRPC became ready."
    }
}

if ($grpcReady) {

    Write-Host ""
    Write-Host "gRPC: READY"
    Write-Host "Endpoint: $grpcHost`:$grpcPort"

}
else {

    Write-Host ""
    Write-Host "WARNING: gRPC did not become ready."
    Write-Host "Emulator is still running."
    Write-Host "The WebRTC gateway cannot start until gRPC is available."
}

# ============================================================
# FINAL STATUS
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " ANDROID26 STATUS"
Write-Host "============================================================"

$stillRunning = Get-Process `
    -Id $emuProcess.Id `
    -ErrorAction SilentlyContinue

if (-not $stillRunning) {
    throw "Android26 stopped."
}

Write-Host "Emulator : RUNNING"
Write-Host "PID      : $($emuProcess.Id)"
Write-Host "AVD      : $avd"
Write-Host "Android  : 8.0 / API 26"
Write-Host "ABI      : x86"
Write-Host "gRPC     : $grpcHost`:$grpcPort"

Write-Host ""
Write-Host "============================================================"
Write-Host " WEBRTC GATEWAY STATUS"
Write-Host "============================================================"

if ($grpcReady) {

    Write-Host "gRPC transport is ready."
    Write-Host "A compatible WebRTC gateway can now connect."

}
else {

    Write-Host "Gateway NOT started because gRPC is not ready."
    Write-Host "Emulator remains running for diagnostics."
}

Write-Host ""
Write-Host "RDP/Tailscale setup remains unchanged."
Write-Host "============================================================"
