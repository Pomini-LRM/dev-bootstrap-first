#!/usr/bin/env bash
# =============================================================================
# dev-bootstrap-first-run.sh
# First-run launcher for dev-bootstrap on a clean Linux/macOS machine.
# Does not require Git or PowerShell 7. Requires Bash and Internet access.
#
# Steps:
#   1. Download the dev-bootstrap repository ZIP from GitHub.
#   2. Extract it into $DEST/repo (using unzip, or python3 zipfile fallback).
#   3. Run install-prerequisites-linux.sh (installs PowerShell 7).
#   4. Run setup-config-interactive.ps1 (interactive configuration).
#   5. Run dev-bootstrap.ps1 (full bootstrap).
#   6. Copy generated config.json and .env into the final repository folder.
#   7. Clean up the staging folder.
#
# Environment variables (optional):
#   DEV_BOOTSTRAP_DEST   - staging folder. Default: $HOME/PominiLRM/dev-bootstrap-first
#   DEV_BOOTSTRAP_FINAL  - final repo folder. Default: $HOME/PominiLRM/dev-bootstrap
#   DEV_BOOTSTRAP_REF    - branch/tag to download. Default: main
#
# Flags:
#   --force          re-download even if the repo is already extracted
#   --keep           do not delete the staging folder at the end
#   --dest <path>    override staging folder
#   --final <path>   override final folder
#   --ref <branch>   override branch/tag
# =============================================================================

set -uo pipefail

DEST="${DEV_BOOTSTRAP_DEST:-$HOME/PominiLRM/dev-bootstrap-first}"
FINAL_TARGET="${DEV_BOOTSTRAP_FINAL:-$HOME/PominiLRM/dev-bootstrap}"
REF="${DEV_BOOTSTRAP_REF:-main}"
FORCE=0
KEEP=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force|-f) FORCE=1; shift ;;
        --keep)     KEEP=1;  shift ;;
        --dest)     DEST="$2";         shift 2 ;;
        --final)    FINAL_TARGET="$2"; shift 2 ;;
        --ref)      REF="$2";          shift 2 ;;
        *) echo "Unknown argument: $1" >&2; shift ;;
    esac
done

REPO_URL="https://github.com/Pomini-LRM/dev-bootstrap/archive/refs/heads/${REF}.zip"
EXTRACTED_DIR_NAME="dev-bootstrap-${REF}"
TMP_DIR="$DEST/_tmp"
EXTRACT_DIR="$TMP_DIR/extract"
ZIP_FILE="$TMP_DIR/dev-bootstrap.zip"
REPO_DIR="$DEST/repo"
LOG_DIR="$DEST/logs"
LOG_FILE="$LOG_DIR/first-run.log"

mkdir -p "$DEST" "$TMP_DIR" "$LOG_DIR"

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE"
}

fail() {
    local code="$1"; shift
    log "ERROR: $*"
    echo "[ERROR] $*" >&2
    echo "        See $LOG_FILE for details." >&2
    cleanup_staging
    exit "$code"
}

cleanup_staging() {
    if [[ "$KEEP" -eq 1 ]]; then
        log "Keep flag set. Staging folder preserved at $DEST."
        echo "Staging folder preserved at: $DEST"
        return
    fi
    if [[ -d "$DEST" ]]; then
        log "Removing staging folder $DEST"
        # Preserve log file in /tmp before deletion.
        if [[ -f "$LOG_FILE" ]]; then
            cp -f "$LOG_FILE" "/tmp/dev-bootstrap-first-run.log" 2>/dev/null || true
        fi
        rm -rf "$DEST" || true
        echo "Staging folder removed. Log saved to /tmp/dev-bootstrap-first-run.log"
    fi
}

log "============================================================"
log "dev-bootstrap first-run launcher started"
log "Staging (DEST) : $DEST"
log "Final target   : $FINAL_TARGET"
log "Repo URL       : $REPO_URL"
log "Force          : $FORCE"
log "Keep staging   : $KEEP"
log "============================================================"

cat <<EOF

============================================================
 dev-bootstrap - First Run Launcher
============================================================
 Staging folder : $DEST
 Final folder   : $FINAL_TARGET
 Source         : $REPO_URL
 Log file       : $LOG_FILE
============================================================

EOF

# ---- Step 1: Download -------------------------------------------------------
if [[ "$FORCE" -eq 0 && -f "$REPO_DIR/dev-bootstrap.ps1" ]]; then
    log "Repository already present at $REPO_DIR. Skipping download."
    echo "[SKIP] Repository already present. Use --force to re-download."
else
    rm -f  "$ZIP_FILE"
    rm -rf "$EXTRACT_DIR" "$REPO_DIR"
    mkdir -p "$EXTRACT_DIR"

    echo "[1/5] Downloading repository ZIP..."
    log "Downloading $REPO_URL to $ZIP_FILE"

    DOWNLOAD_OK=0
    if command -v curl >/dev/null 2>&1; then
        if curl -L --fail --silent --show-error -o "$ZIP_FILE" "$REPO_URL" >> "$LOG_FILE" 2>&1; then
            DOWNLOAD_OK=1
        fi
    fi
    if [[ "$DOWNLOAD_OK" -eq 0 ]] && command -v wget >/dev/null 2>&1; then
        if wget -q -O "$ZIP_FILE" "$REPO_URL" >> "$LOG_FILE" 2>&1; then
            DOWNLOAD_OK=1
        fi
    fi
    [[ "$DOWNLOAD_OK" -eq 1 ]] || fail 10 "Download failed. Install curl or wget and retry."
    echo "       Download OK."

    # ---- Step 2: Extract ----------------------------------------------------
    echo "[2/5] Extracting archive..."
    log "Extracting $ZIP_FILE into $EXTRACT_DIR"

    EXTRACT_OK=0
    if command -v unzip >/dev/null 2>&1; then
        if unzip -q "$ZIP_FILE" -d "$EXTRACT_DIR" >> "$LOG_FILE" 2>&1; then
            EXTRACT_OK=1
        fi
    fi
    if [[ "$EXTRACT_OK" -eq 0 ]] && command -v python3 >/dev/null 2>&1; then
        log "Falling back to python3 zipfile extraction."
        if python3 -c "import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" \
            "$ZIP_FILE" "$EXTRACT_DIR" >> "$LOG_FILE" 2>&1; then
            EXTRACT_OK=1
        fi
    fi
    [[ "$EXTRACT_OK" -eq 1 ]] || fail 20 "Could not extract the archive. Install unzip or python3."
    echo "       Extraction OK."

    # ---- Step 3: Locate ----------------------------------------------------
    echo "[3/5] Locating extracted repository..."
    FOUND_DIR=""
    if [[ -f "$EXTRACT_DIR/$EXTRACTED_DIR_NAME/dev-bootstrap.ps1" ]]; then
        FOUND_DIR="$EXTRACT_DIR/$EXTRACTED_DIR_NAME"
    else
        for d in "$EXTRACT_DIR"/*/; do
            if [[ -f "$d/dev-bootstrap.ps1" ]]; then
                FOUND_DIR="${d%/}"
                break
            fi
        done
    fi
    [[ -n "$FOUND_DIR" ]] || fail 30 "Extracted archive does not contain dev-bootstrap.ps1."

    log "Extracted repo at: $FOUND_DIR"
    mv "$FOUND_DIR" "$REPO_DIR" || fail 31 "Could not stage repository into $REPO_DIR."
    echo "       Repository staged at $REPO_DIR."
fi

[[ -f "$REPO_DIR/dev-bootstrap.ps1" ]] || fail 40 "Bootstrap entry point not found at $REPO_DIR/dev-bootstrap.ps1."

# ---- Step 4: Prerequisites --------------------------------------------------
echo "[4/5] Installing prerequisites (PowerShell 7)..."
PREREQ_SCRIPT="$REPO_DIR/scripts/install-prerequisites-linux.sh"
if [[ -f "$PREREQ_SCRIPT" ]]; then
    chmod +x "$PREREQ_SCRIPT" || true
    if ! bash "$PREREQ_SCRIPT"; then
        log "WARNING: install-prerequisites-linux.sh returned a non-zero exit code."
        echo "[WARN] Prerequisite installer reported issues. Continuing anyway."
    fi
else
    log "WARNING: $PREREQ_SCRIPT not found, skipping."
    echo "[WARN] Prerequisites script not found. Skipping."
fi

# ---- Step 5: Setup + bootstrap ---------------------------------------------
echo "[5/5] Running interactive setup and bootstrap..."

if ! command -v pwsh >/dev/null 2>&1; then
    fail 60 "PowerShell 7 (pwsh) not found after prerequisites step. Open a new shell and re-run."
fi

SETUP_SCRIPT="$REPO_DIR/scripts/setup-config-interactive.ps1"
if [[ -f "$SETUP_SCRIPT" ]]; then
    log "Running setup-config-interactive.ps1"
    if ! pwsh -NoProfile -ExecutionPolicy Bypass -File "$SETUP_SCRIPT"; then
        fail 70 "Interactive configuration failed."
    fi
else
    log "WARNING: setup-config-interactive.ps1 not found, skipping."
    echo "[WARN] Interactive setup script not found. Skipping."
fi

log "Running dev-bootstrap.ps1"
(
    cd "$REPO_DIR"
    pwsh -NoProfile -ExecutionPolicy Bypass -File "$REPO_DIR/dev-bootstrap.ps1"
)
BOOTSTRAP_RC=$?
log "dev-bootstrap.ps1 exited with code $BOOTSTRAP_RC"
if [[ "$BOOTSTRAP_RC" -ne 0 ]]; then
    fail "$BOOTSTRAP_RC" "dev-bootstrap.ps1 returned exit code $BOOTSTRAP_RC."
fi

# ---- Step 6: Copy config files to final folder ------------------------------
echo
echo "Copying generated config files to $FINAL_TARGET ..."
log "Copying generated config.json and .env to final folder."

SRC_CONFIG="$REPO_DIR/config/config.json"
SRC_ENV="$REPO_DIR/.env"

mkdir -p "$FINAL_TARGET/config"

if [[ -f "$SRC_CONFIG" ]]; then
    cp -f "$SRC_CONFIG" "$FINAL_TARGET/config/config.json"
    log "Copied config.json -> $FINAL_TARGET/config/config.json"
    echo "       config.json copied."
else
    log "WARNING: $SRC_CONFIG not found, nothing to copy."
    echo "[WARN] config.json was not generated."
fi
if [[ -f "$SRC_ENV" ]]; then
    cp -f "$SRC_ENV" "$FINAL_TARGET/.env"
    log "Copied .env -> $FINAL_TARGET/.env"
    echo "       .env copied."
else
    log "WARNING: $SRC_ENV not found, nothing to copy."
    echo "[WARN] .env was not generated."
fi

# ---- Step 7: Cleanup --------------------------------------------------------
cleanup_staging

echo
echo "============================================================"
echo " dev-bootstrap first-run completed successfully."
echo "============================================================"
exit 0
