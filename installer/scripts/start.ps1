. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "common.ps1")
Write-Host "=== Nemesis: Lockdown - local multiplayer: START ===" -ForegroundColor Cyan

$game = Find-GamePath
if (-not $game) { Write-Host "The game is not installed/configured. Run 'Install.bat' first." -ForegroundColor Red; Read-Host "Press Enter to exit"; exit 1 }
$exe = Join-Path $game "NemesisLD\Binaries\Win64\NemesisLD-Win64-Shipping.exe"
$pak = Join-Path $game "NemesisLD\Content\Paks\zzz_NemesisLocalHost_P.pak"
if (-not (Test-Path $pak)) { Write-Host "The patch is not installed. Run 'Install.bat' first." -ForegroundColor Red; Read-Host "Press Enter to exit"; exit 1 }

# Steam must be running
if (-not (Get-Process steam -ErrorAction SilentlyContinue)) {
    Write-Host "Steam is not running, starting it..." -ForegroundColor Yellow
    Start-Process "steam://open/main" | Out-Null
    $t = 0; while (-not (Get-Process steam -ErrorAction SilentlyContinue) -and $t -lt 60) { Start-Sleep 2; $t += 2 }
    Start-Sleep 8
}

# local backend (if not already running)
$listening = netstat -ano | Select-String "127\.0\.0\.1:8888\s.*LISTENING"
$backend = $null
if (-not $listening) {
    $backendExe = Join-Path $PkgDir "backend\NemesisLocalBackend.exe"
    $backend = Start-Process -FilePath $backendExe -WorkingDirectory (Split-Path $backendExe) -WindowStyle Hidden -PassThru
    Start-Sleep 2
    Write-Host "Local backend started." -ForegroundColor Green
} else { Write-Host "Local backend is already running." -ForegroundColor Green }

# game
Write-Host "Starting the game..." -ForegroundColor Green
$g = Start-Process -FilePath $exe -ArgumentList "NemesisLD","-httpproxy=127.0.0.1:8888" -WorkingDirectory (Split-Path $exe) -PassThru
Write-Host "The game is running (PID $($g.Id)). You can minimize this window; it will close when you quit the game."
$g.WaitForExit()

# stop the backend and any leftover local server
if ($backend -and -not $backend.HasExited) { Stop-Process -Id $backend.Id -Force -ErrorAction SilentlyContinue }
Get-Process NemesisLDServer-Win64-Shipping -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Write-Host "Game closed. Goodbye."
