. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "common.ps1")
Write-Host "=== Nemesis: Lockdown - local multiplayer: INSTALL ===" -ForegroundColor Cyan

$game = Get-GamePathInteractive
Write-Host "Game folder: $game"

$clientPaks = Join-Path $game "NemesisLD\Content\Paks"
$serverPaks = Join-Path $game "NemesisLD\Source\WindowsServer\NemesisLD\Content\Paks"
$clientBin  = Join-Path $game "NemesisLD\Binaries\Win64"
foreach ($d in $clientPaks, $serverPaks, $clientBin) { if (-not (Test-Path $d)) { throw "Folder does not exist: $d (is the game installation complete?)" } }

# 1) patch paks
Copy-Item (Join-Path $PkgDir "paks\client\zzz_NemesisLocalHost_P.pak") (Join-Path $clientPaks "zzz_NemesisLocalHost_P.pak") -Force
Copy-Item (Join-Path $PkgDir "paks\server\zzz_NemesisLocalHost_P.pak") (Join-Path $serverPaks "zzz_NemesisLocalHost_P.pak") -Force
Write-Host "[1/3] Patch paks copied." -ForegroundColor Green

# 2) steam_appid.txt next to the client exe (so the game can be started directly with parameters)
Set-Content -Path (Join-Path $clientBin "steam_appid.txt") -Value "1915550" -NoNewline -Encoding ascii
Write-Host "[2/3] steam_appid.txt written." -ForegroundColor Green

# 3) Engine.ini: allow the local backend (self-signed certificate)
$iniDir = Join-Path $env:LOCALAPPDATA "NemesisLD\Saved\Config\WindowsNoEditor"
New-Item -ItemType Directory -Force -Path $iniDir | Out-Null
$ini = Join-Path $iniDir "Engine.ini"
$content = if (Test-Path $ini) { Get-Content $ini -Raw } else { "" }
if ($content -notmatch "n\.VerifyPeer=False") {
    $content = "[/Script/Engine.NetworkSettings]`r`nn.VerifyPeer=False`r`n`r`n" + $content
    Set-Content -Path $ini -Value $content -Encoding ascii
}
Write-Host "[3/3] Engine.ini configured." -ForegroundColor Green

Write-Host ""
Write-Host "DONE. From now on start the game with 'Start Nemesis.bat' from this folder." -ForegroundColor Cyan
Write-Host "(Starting from Steam still works for solo play, but the multiplayer menu will say 'outdated'.)"
