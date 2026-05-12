# dev-bootstrap-first

First-run launcher for [`dev-bootstrap`](https://github.com/Pomini-LRM/dev-bootstrap).
Designed for **non-technical users on a fresh machine** that has neither Git nor PowerShell 7
installed. The launcher downloads the `dev-bootstrap` repository as a ZIP archive, installs
the prerequisites, runs the interactive configuration wizard, and finally executes the full
bootstrap.

---

## TL;DR — what you get

- **Windows**: a single `.cmd` file. Double click and follow the prompts.
- **Linux / macOS**: a single `.sh` file. Run it from a terminal.

No `git`, no `pwsh`, no `7zip`, no Python required up front.

---

## Windows (1 click)

1. Download
   [`dev-bootstrap-first-run.cmd`](dev-bootstrap-first-run.cmd)
   (or the latest release asset — see [Releases](#releases-recommended-distribution)).
2. Place it anywhere on disk (for example on the Desktop).
3. **Double click** the file.
4. Follow the prompts (GitHub token, Azure DevOps PAT, etc.) when asked.

The launcher will:

1. Create the staging folder `%USERPROFILE%\PominiLRM\dev-bootstrap-first` (configurable).
2. Download the ZIP from
   `https://github.com/Pomini-LRM/dev-bootstrap/archive/refs/heads/main.zip` using `curl`,
   falling back to `bitsadmin` if `curl` is missing.
3. Extract it with `tar -xf`, then `Expand-Archive`, then a VBScript fallback.
4. Run `scripts\install-prerequisites-windows.ps1` (installs **PowerShell 7**).
5. Run `scripts\setup-config-interactive.ps1` (interactive configuration wizard).
6. Run `dev-bootstrap.ps1` (full bootstrap: Git, tools, repo cloning, ACR images, ...).
7. Copy the generated `config.json` and `.env` into the handoff folder
   (default `%USERPROFILE%\PominiLRM\dev-bootstrap`).
8. Delete the staging folder.

`dev-bootstrap` will automatically import these files on its next run and remove the
handoff folder.

A full log is saved to `%USERPROFILE%\PominiLRM\dev-bootstrap-first\logs\first-run.log` while the run is in
progress, and to `%TEMP%\dev-bootstrap-first-run.log` after cleanup.

### Customizing the Windows launcher

Environment variables (set them before launching the `.cmd`):

| Variable               | Default                                          | Purpose                                      |
| ---------------------- | ------------------------------------------------ | -------------------------------------------- |
| `DEV_BOOTSTRAP_DEST`   | `%USERPROFILE%\PominiLRM\dev-bootstrap-first`    | Staging folder (download + extract).         |
| `DEV_BOOTSTRAP_FINAL`  | `%USERPROFILE%\PominiLRM\dev-bootstrap`           | Handoff folder for `config.json` and `.env`. |
| `DEV_BOOTSTRAP_REF`    | `main`                                           | Branch or tag of `dev-bootstrap` to use.     |

Command-line flags (run from `cmd.exe`):

```cmd
dev-bootstrap-first-run.cmd --force
dev-bootstrap-first-run.cmd --keep
dev-bootstrap-first-run.cmd --dest  "C:\tmp\db"
dev-bootstrap-first-run.cmd --final "C:\code\dev-bootstrap"
dev-bootstrap-first-run.cmd --ref   develop
```

- `--force`: re-download the ZIP even if the repository is already staged.
- `--keep`: do not delete the staging folder at the end (useful for debugging).

---

## Linux / macOS (1 command)

```bash
curl -fsSLO https://github.com/Pomini-LRM/dev-bootstrap-first/releases/latest/download/dev-bootstrap-first-run.sh
chmod +x dev-bootstrap-first-run.sh
./dev-bootstrap-first-run.sh
```

> See [QUICK_START.md](QUICK_START.md) for a condensed step-by-step reference.

The launcher mirrors the Windows behavior:

- Downloads with `curl`, falls back to `wget`.
- Extracts with `unzip`, falls back to `python3 -c 'import zipfile; ...'`.
- Runs `scripts/install-prerequisites-linux.sh`, then
  `scripts/setup-config-interactive.ps1`, then `dev-bootstrap.ps1`.
- Copies `config.json` and `.env` into the final folder.
- Removes the staging folder.

### Customizing the Linux/macOS launcher

| Variable               | Default                                          |
| ---------------------- | ------------------------------------------------ |
| `DEV_BOOTSTRAP_DEST`   | `$HOME/PominiLRM/dev-bootstrap-first`            |
| `DEV_BOOTSTRAP_FINAL`  | `$HOME/PominiLRM/dev-bootstrap`                  |
| `DEV_BOOTSTRAP_REF`    | `main`                                           |

Flags: `--force`, `--keep`, `--dest <path>`, `--final <path>`, `--ref <branch>`.

---

## Releases (recommended distribution)

For end users it is strongly recommended to publish stable download links via GitHub Releases:

- `https://github.com/Pomini-LRM/dev-bootstrap-first/releases/latest/download/dev-bootstrap-first-run.cmd`
- `https://github.com/Pomini-LRM/dev-bootstrap-first/releases/latest/download/dev-bootstrap-first-run.sh`

Attach both files as Release assets so the URL above stays stable across versions.

---

## Repository layout

```
dev-bootstrap-first-run.cmd   Windows entry point (pure CMD, double click)
dev-bootstrap-first-run.sh    Linux/macOS entry point (bash)
QUICK_START.md                Condensed step-by-step reference
SECURITY.md                   Vulnerability reporting policy
CONTRIBUTING.md               How to contribute
LICENSE                       MIT license
README.md                     This document
```

---

## Testing on a clean machine

### Windows

1. Spin up a fresh Windows 10/11 VM (no Git, no PowerShell 7, only built-in
   Windows PowerShell 5.1).
2. Copy `dev-bootstrap-first-run.cmd` to the Desktop.
3. Double click it.
4. Watch the steps:
   - Download (`curl` is shipped with Windows 10 1803+; `bitsadmin` is the fallback).
   - Extraction (`tar` is shipped with Windows 10 1803+; `Expand-Archive` and the VBS
     fallback cover older systems).
   - Prerequisite installer (PowerShell 7 via `winget`).
   - Interactive setup wizard.
   - `dev-bootstrap.ps1` full run.
5. Verify that:
   - `%USERPROFILE%\PominiLRM\dev-bootstrap\config\config.json` exists (handoff folder).
   - `%USERPROFILE%\PominiLRM\dev-bootstrap\.env` exists (handoff folder).
   - `%USERPROFILE%\PominiLRM\dev-bootstrap-first` has been removed.
   - `%TEMP%\dev-bootstrap-first-run.log` contains the full run history.

To test re-runs without re-downloading: use `--force` to retest a clean run, or `--keep`
to inspect intermediate artifacts.

### Linux / macOS

1. Use a fresh container or VM (for example `docker run -it ubuntu:22.04`).
2. Install the bare minimum: `apt-get update && apt-get install -y curl unzip ca-certificates sudo`.
3. Copy `dev-bootstrap-first-run.sh` into the container.
4. Run `./dev-bootstrap-first-run.sh`.
5. Verify the same outcomes as on Windows, using the Linux paths.

---

## Troubleshooting

| Symptom                                       | Likely cause / fix                                                                       |
| --------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `[ERROR] Download failed`                     | No Internet, blocked by proxy/firewall, or invalid `DEV_BOOTSTRAP_REF`. Check the log.   |
| `[ERROR] Could not extract the archive`       | Disk full or insufficient permissions on `DEV_BOOTSTRAP_DEST`. Run as Administrator.     |
| `[ERROR] Bootstrap entry point not found`     | The ZIP layout changed. Set `DEV_BOOTSTRAP_REF` to a tag known to contain the script.    |
| `[ERROR] PowerShell 7 was not installed`      | `winget` was unavailable. Install PowerShell 7 manually, then re-run the launcher.       |
| `setup-config-interactive.ps1 failed`         | Configuration values are invalid. Re-run with `--keep` and re-launch the script by hand. |
| Final folder missing, config files not copied | Handoff folder could not be created. Check permissions on `DEV_BOOTSTRAP_FINAL`. |

All steps log to `<DEST>/logs/first-run.log` while running, and to
`%TEMP%\dev-bootstrap-first-run.log` (Windows) / `/tmp/dev-bootstrap-first-run.log`
(Linux/macOS) after cleanup.

---

## Security notes

- The launcher downloads from `https://github.com/Pomini-LRM/dev-bootstrap` over HTTPS.
- It does **not** require Administrator/`sudo` to download or extract; only the
  prerequisite installers may prompt for elevation (PowerShell 7, `winget`/`apt`).
- No tokens or secrets are stored in `dev-bootstrap-first`. They are handled by the
  downstream `setup-config-interactive.ps1` and `dev-bootstrap.ps1` scripts.
- Inspect the source of either launcher before running on a managed workstation.

---

## License

MIT — see [LICENSE](LICENSE).
