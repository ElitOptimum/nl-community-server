. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "common.ps1")
Write-Host "=== Nemesis: Lockdown - local multiplayer: UNINSTALL ===" -ForegroundColor Cyan
$game = Find-GamePath
if (-not $game) { Write-Host "Game folder not found, nothing to remove." -ForegroundColor Yellow; Read-Host "Press Enter to exit"; exit 0 }
Get-Process NemesisLD-Win64-Shipping, NemesisLDServer-Win64-Shipping, NemesisLocalBackend -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
$files = @(
    (Join-Path $game "NemesisLD\Content\Paks\zzz_NemesisLocalHost_P.pak"),
    (Join-Path $game "NemesisLD\Source\WindowsServer\NemesisLD\Content\Paks\zzz_NemesisLocalHost_P.pak"),
    (Join-Path $game "NemesisLD\Binaries\Win64\steam_appid.txt")
)
foreach ($f in $files) { if (Test-Path $f) { Remove-Item $f -Force; Write-Host "Deleted: $f" } }
$ini = Join-Path $env:LOCALAPPDATA "NemesisLD\Saved\Config\WindowsNoEditor\Engine.ini"
if (Test-Path $ini) {
    $c = Get-Content $ini -Raw
    $c = $c -replace "\[/Script/Engine\.NetworkSettings\]\r?\nn\.VerifyPeer=False\r?\n\r?\n?", ""
    Set-Content -Path $ini -Value $c -Encoding ascii
    Write-Host "Engine.ini restored."
}
if (Test-Path $GamePathFile) { Remove-Item $GamePathFile -Force }
Write-Host "DONE. The game is back to its original state (Steam 'Verify integrity' is not needed)." -ForegroundColor Green
