# Contributing to dev-bootstrap-first

Thank you for your interest in contributing. This repository contains two shell
launchers — one for Windows CMD and one for Bash — plus documentation. The bar for
tooling is intentionally low.

## Prerequisites

No special tools are required to edit `.cmd` or `.sh` files. To test changes:

- **Windows**: a `cmd.exe` session on Windows 10 / 11.
- **Linux / macOS**: Bash 4+ and at minimum `curl` + `unzip`.

For a full end-to-end test, a clean VM or container without Git / PowerShell 7 is
the most reliable environment.

## Making changes

1. Fork the repository and create a branch from `main`.
2. Edit `dev-bootstrap-first-run.cmd` or `dev-bootstrap-first-run.sh`.
3. Test on a clean machine (see [QUICK_START.md](QUICK_START.md) — *Testing on a clean machine*).
4. Update `README.md` and `QUICK_START.md` if the behaviour or flags change.
5. Open a pull request against `main` with a clear description of the change.

## Coding conventions

### Windows (.cmd)

- Use `setlocal EnableExtensions EnableDelayedExpansion` at the top.
- Prefer `where <tool>` checks before using optional tools.
- Log every non-trivial action with `:log`.
- Return a documented exit code on every error path.
- Keep batch labels lowercase and prefixed with the feature (e.g., `:cleanup_and_exit`).

### Linux / macOS (.sh)

- Start with `#!/usr/bin/env bash` and `set -uo pipefail`.
- Use the `fail <code> <message>` helper for all error paths.
- Prefer `command -v <tool>` for presence checks.
- Use `log` for every non-trivial action.

## Commit messages

Use conventional commits:

```
feat: add --proxy flag to launcher
fix: bitsadmin fallback on Windows Server 2019
docs: update troubleshooting table
```

## Reporting issues

Open a GitHub issue with:
- OS version and build.
- The content of `%TEMP%\dev-bootstrap-first-run.log` or `/tmp/dev-bootstrap-first-run.log`.
- The exact error message printed to the console.
