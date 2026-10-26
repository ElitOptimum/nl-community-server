# Shared functions: locating the game folder
$ErrorActionPreference = "Stop"
$PkgDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$GamePathFile = Join-Path $PkgDir "game_path.txt"

function Find-GamePath {
    # 1) remembered path
    if (Test-Path $GamePathFile) {
        $p = (Get-Content $GamePathFile -Raw).Trim()
        if ($p -and (Test-Path (Join-Path $p "NemesisLD.exe"))) { return $p }
    }
    # 2) Steam registry + libraryfolders.vdf
    $libs = @()
    try {
        $steam = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction Stop).SteamPath
        if ($steam) {
            $steam = $steam -replace "/", "\"
            $libs += $steam
            $vdf = Join-Path $steam "steamapps\libraryfolders.vdf"
            if (Test-Path $vdf) {
                foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) {
                    $libs += ($m.Groups[1].Value -replace "\\\\", "\")
                }
            }
        }
    } catch {}
    foreach ($d in "C:","D:","E:","F:") { $libs += "$d\SteamLibrary"; $libs += "$d\Program Files (x86)\Steam"; $libs += "$d\Steam" }
    foreach ($lib in ($libs | Select-Object -Unique)) {
        $cand = Join-Path $lib "steamapps\common\Nemesis - Lockdown"
        if (Test-Path (Join-Path $cand "NemesisLD.exe")) { return $cand }
    }
    return $null
}

function Get-GamePathInteractive {
    $p = Find-GamePath
    while (-not $p) {
        Write-Host ""
        Write-Host "Could not find the game folder. Enter the path to the 'Nemesis - Lockdown' folder" -ForegroundColor Yellow
        Write-Host "(example: D:\SteamLibrary\steamapps\common\Nemesis - Lockdown)"
        $in = Read-Host "Path"
        if ($in -and (Test-Path (Join-Path $in "NemesisLD.exe"))) { $p = $in } else { Write-Host "NemesisLD.exe is not in that folder, try again." -ForegroundColor Red }
    }
    Set-Content -Path $GamePathFile -Value $p -Encoding ascii
    return $p
}
