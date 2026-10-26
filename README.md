# NL Community Server

An unofficial community tool that brings **multiplayer via local hosting** back to *Nemesis: Lockdown*
(Steam) after the official servers were shut down (August 2026).

> **Disclaimer:** This is an unofficial community project and is **not affiliated with, endorsed by, or
> supported by** Awaken Realms or Inter Studio. *Nemesis: Lockdown* and all related names and content are
> the property of their respective owners. A **legally purchased copy of the game** on Steam is required.
> This repository does not contain any game files.

## For players

1. Download `NemesisLocal.zip` from the [Releases](../../releases) page and extract it anywhere (e.g. the Desktop).
2. Double-click **`Install.bat`** (once).
3. Always start the game with **`Start Nemesis.bat`**.
4. **`Uninstall.bat`** removes all changes.

Detailed instructions (hosting a server, joining, troubleshooting): [installer/INSTRUCTIONS.txt](installer/INSTRUCTIONS.txt).
Serbian: [installer/UPUTSTVO.txt](installer/UPUTSTVO.txt).

## How it works

- `backend/backend.js` is a small HTTP(S) proxy on `127.0.0.1:8888`. The game is started with
  `-httpproxy=127.0.0.1:8888`, and the proxy answers calls to the shut-down backend (e.g. the version check)
  from `backend/responses/`. All other traffic (Steam etc.) is forwarded unchanged. It runs only on the local computer.
- On first run the backend creates its own self-signed certificate in `backend/cert/` (unique to each computer).
- The installer copies two small patch paks that enable the local hosting mode built into the game, writes
  `steam_appid.txt` and adds `n.VerifyPeer=False` to the user's `Engine.ini`. `Uninstall.bat` reverts everything.

The patch paks contain a modified game file, so they are not committed to git. They are distributed only in the
zip on the Releases page.

## Build (for maintainers)

Requires: Windows, Node 18+.

```powershell
npm install
npm run build:backend                                                # -> build\NemesisLocalBackend.exe
npm run build:dist -- -PaksDir <folder with client\ and server\ paks>   # -> dist\NemesisLocal.zip
```

For development: `npm start` runs the backend directly.

## License

The source code in this repository is licensed under the [MIT License](LICENSE). The license does not cover the
game or any of its content.
