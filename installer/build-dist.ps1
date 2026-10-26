# build-dist.ps1 : assembles the player package dist/NemesisLocal (+ dist/NemesisLocal.zip for a GitHub Release)
# Run first: npm run build:backend (build/NemesisLocalBackend.exe).
# The patch paks are NOT in this repository; -PaksDir points to a folder with client\ and server\ subfolders.
param(
    [string]$PaksDir = (Join-Path $PSScriptRoot "..\paks")
)
$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$Out = Join-Path $Root "dist\NemesisLocal"

$need = @(
    (Join-Path $Root "build\NemesisLocalBackend.exe"),
    (Join-Path $PaksDir "client\zzz_NemesisLocalHost_P.pak"),
    (Join-Path $PaksDir "server\zzz_NemesisLocalHost_P.pak")
)
foreach ($f in $need) { if (-not (Test-Path $f)) { throw "Missing $f" } }

if (Test-Path $Out) { Remove-Item $Out -Recurse -Force }
New-Item -ItemType Directory -Force -Path "$Out\backend", "$Out\paks\client", "$Out\paks\server", "$Out\scripts" | Out-Null

Copy-Item "$PSScriptRoot\*.bat", "$PSScriptRoot\INSTRUCTIONS.txt", "$PSScriptRoot\UPUTSTVO.txt" $Out
Copy-Item "$PSScriptRoot\scripts\*.ps1" "$Out\scripts"
Copy-Item "$Root\build\NemesisLocalBackend.exe" "$Out\backend"
Copy-Item "$Root\backend\responses" "$Out\backend" -Recurse
# no cert\ : the backend creates its own certificate on the player's computer on first run
Copy-Item (Join-Path $PaksDir "client\zzz_NemesisLocalHost_P.pak") "$Out\paks\client"
Copy-Item (Join-Path $PaksDir "server\zzz_NemesisLocalHost_P.pak") "$Out\paks\server"

$zip = Join-Path $Root "dist\NemesisLocal.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path $Out -DestinationPath $zip
Write-Host "Done: $Out and $zip" -ForegroundColor Green
