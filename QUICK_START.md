# Quick Start

## Windows

### Minimum requirement

Any Windows 10 / 11 machine with `cmd.exe`. No Git, no PowerShell 7 needed.

### 1. Download

Download the launcher from the latest release:

```
https://github.com/Pomini-LRM/dev-bootstrap-first/releases/latest/download/dev-bootstrap-first-run.cmd
```

Or directly from the repository:

[dev-bootstrap-first-run.cmd](dev-bootstrap-first-run.cmd)

### 2. Run

Double click `dev-bootstrap-first-run.cmd`.

A console window opens and runs automatically. Follow the on-screen prompts
(GitHub token, Azure DevOps PAT, etc.) when asked.

### 3. What happens

| Step | Action |
|------|--------|
| 1 | Creates staging folder `%USERPROFILE%\PominiLRM\dev-bootstrap-first` |
| 2 | Downloads the `dev-bootstrap` ZIP from GitHub (curl → bitsadmin fallback) |
| 3 | Extracts it (tar → Expand-Archive → VBScript fallback) |
| 4 | Runs `install-prerequisites-windows.ps1` — installs **PowerShell 7** |
| 5 | Runs `setup-config-interactive.ps1` — interactive configuration wizard |
| 6 | Runs `dev-bootstrap.ps1` — full bootstrap (Git, tools, repos, ACR images) |
| 7 | Copies `config.json` and, when present, `.env` to `%USERPROFILE%\PominiLRM\dev-bootstrap` |
| 8 | Removes the staging folder |

Log: `%USERPROFILE%\PominiLRM\dev-bootstrap-first\logs\first-run.log` (during run),
`%TEMP%\dev-bootstrap-first-run.log` (after cleanup).

### Customization

Set these environment variables **before** launching the `.cmd`:

| Variable              | Default                                          | Description                         |
|-----------------------|--------------------------------------------------|-------------------------------------|
| `DEV_BOOTSTRAP_DEST`  | `%USERPROFILE%\PominiLRM\dev-bootstrap-first`    | Staging folder                      |
| `DEV_BOOTSTRAP_FINAL` | `%USERPROFILE%\PominiLRM\dev-bootstrap`           | Handoff folder for generated configs|
| `DEV_BOOTSTRAP_REF`   | `main`                                           | Branch or tag to download           |
| `DEV_BOOTSTRAP_DEBUG` | `0`                                              | `1` enables additional debug messages in console and log |

Or pass flags from the command line:

```cmd
dev-bootstrap-first-run.cmd --force
dev-bootstrap-first-run.cmd --keep
dev-bootstrap-first-run.cmd --dest  "C:\staging"
dev-bootstrap-first-run.cmd --final "C:\code\dev-bootstrap"
dev-bootstrap-first-run.cmd --ref   develop
```

Enable debug output when troubleshooting:

```cmd
set DEV_BOOTSTRAP_DEBUG=1
dev-bootstrap-first-run.cmd --keep
```

---

## Linux / macOS

### Minimum requirement

Bash and Internet access. `curl` or `wget`. `unzip` or `python3`.

### 1. Download and run

```bash
curl -fsSLO https://github.com/Pomini-LRM/dev-bootstrap-first/releases/latest/download/dev-bootstrap-first-run.sh
chmod +x dev-bootstrap-first-run.sh
./dev-bootstrap-first-run.sh
```

### 2. What happens

Same steps as Windows, using:
- `curl` / `wget` for download
- `unzip` / `python3 zipfile` for extraction
- `install-prerequisites-linux.sh` for PowerShell 7

### Customization

| Variable              | Default                                          |
|-----------------------|--------------------------------------------------|
| `DEV_BOOTSTRAP_DEST`  | `$HOME/PominiLRM/dev-bootstrap-first`            |
| `DEV_BOOTSTRAP_FINAL` | `$HOME/PominiLRM/dev-bootstrap`                  |
| `DEV_BOOTSTRAP_REF`   | `main`                                           |

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Download fails | Check Internet / proxy. Use `--ref` if branch changed. |
| Extraction fails | Run as Administrator. Check disk space. |
| PowerShell 7 not installed | Install manually from [aka.ms/pscore6](https://aka.ms/pscore6), then re-run. |
| Final folder missing | Set `DEV_BOOTSTRAP_FINAL` to a writable path and re-run with `--keep`. |

For full documentation, see [README.md](README.md).
