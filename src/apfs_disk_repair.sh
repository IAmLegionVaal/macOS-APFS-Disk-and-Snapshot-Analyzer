#!/bin/bash
set -u

VERIFY_TARGET=""
REPAIR_TARGET=""
SNAPSHOT_VOLUME=""
SNAPSHOT_UUID=""
DRY_RUN=false
ASSUME_YES=false
OUTPUT_DIR=""
FAILURES=0
ACTIONS=0

usage() {
  cat <<'EOF'
Usage: apfs_disk_repair.sh [options]

  --verify-volume TARGET            Verify one mounted volume or disk identifier.
  --repair-volume TARGET            Run First Aid on one mounted volume or identifier.
  --delete-snapshot VOLUME UUID     Delete one selected APFS snapshot by UUID.
  --dry-run                         Show commands without changing the Mac.
  --yes                             Skip confirmation prompts.
  --output DIR                      Save logs and verification output in DIR.
  -h, --help                        Show help.

Examples:
  sudo ./src/apfs_disk_repair.sh --verify-volume /
  sudo ./src/apfs_disk_repair.sh --repair-volume /
  sudo ./src/apfs_disk_repair.sh --delete-snapshot / 12345678-1234-1234-1234-123456789ABC
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --verify-volume) VERIFY_TARGET="${2:-}"; shift 2 ;;
    --repair-volume) REPAIR_TARGET="${2:-}"; shift 2 ;;
    --delete-snapshot) SNAPSHOT_VOLUME="${2:-}"; SNAPSHOT_UUID="${3:-}"; shift 3 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --yes) ASSUME_YES=true; shift ;;
    --output) OUTPUT_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

[ "$(uname -s)" = "Darwin" ] || { echo "This tool must run on macOS." >&2; exit 3; }
[ "$(id -u)" -eq 0 ] || { echo "Run this repair with sudo." >&2; exit 3; }
ACTION_COUNT=0
[ -n "$VERIFY_TARGET" ] && ACTION_COUNT=$((ACTION_COUNT + 1))
[ -n "$REPAIR_TARGET" ] && ACTION_COUNT=$((ACTION_COUNT + 1))
[ -n "$SNAPSHOT_UUID" ] && ACTION_COUNT=$((ACTION_COUNT + 1))
[ "$ACTION_COUNT" -eq 1 ] || { echo "Choose exactly one action." >&2; exit 2; }
if [ -n "$SNAPSHOT_UUID" ]; then
  case "$SNAPSHOT_UUID" in ????????-????-????-????-????????????) : ;; *) echo "Snapshot UUID format is invalid." >&2; exit 2 ;; esac
fi

STAMP="$(date +%Y%m%d_%H%M%S)"
OUTPUT_DIR="${OUTPUT_DIR:-./apfs-repair-$STAMP}"
mkdir -p "$OUTPUT_DIR"
LOG="$OUTPUT_DIR/repair.log"
VERIFY="$OUTPUT_DIR/verification.txt"
BEFORE="$OUTPUT_DIR/before.txt"
: > "$LOG"

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG"; }
confirm() {
  $ASSUME_YES && return 0
  printf '%s [y/N]: ' "$1"
  read -r answer
  case "$answer" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}
run_action() {
  description="$1"; shift
  ACTIONS=$((ACTIONS + 1)); log "$description"
  if $DRY_RUN; then
    printf 'DRY-RUN:' >> "$LOG"; for arg in "$@"; do printf ' %q' "$arg" >> "$LOG"; done; printf '\n' >> "$LOG"; return 0
  fi
  if "$@" >> "$LOG" 2>&1; then log "SUCCESS: $description"; return 0; fi
  FAILURES=$((FAILURES + 1)); log "WARNING: $description failed"; return 1
}
collect_state() {
  destination="$1"
  {
    echo "Collected: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    /usr/sbin/diskutil list 2>&1 || true
    echo
    /usr/sbin/diskutil apfs list 2>&1 || true
    if [ -n "$VERIFY_TARGET" ]; then /usr/sbin/diskutil info "$VERIFY_TARGET" 2>&1 || true; fi
    if [ -n "$REPAIR_TARGET" ]; then /usr/sbin/diskutil info "$REPAIR_TARGET" 2>&1 || true; fi
    if [ -n "$SNAPSHOT_VOLUME" ]; then /usr/sbin/diskutil apfs listSnapshots "$SNAPSHOT_VOLUME" 2>&1 || true; fi
  } > "$destination"
}

collect_state "$BEFORE"

if [ -n "$VERIFY_TARGET" ]; then
  if ! confirm "Verify volume $VERIFY_TARGET?"; then log "Action cancelled."; exit 10; fi
  run_action "Verifying volume $VERIFY_TARGET" /usr/sbin/diskutil verifyVolume "$VERIFY_TARGET" || true
elif [ -n "$REPAIR_TARGET" ]; then
  if ! confirm "Run First Aid on $REPAIR_TARGET? Applications using the volume may be interrupted."; then log "Action cancelled."; exit 10; fi
  run_action "Repairing volume $REPAIR_TARGET" /usr/sbin/diskutil repairVolume "$REPAIR_TARGET" || true
else
  if ! /usr/sbin/diskutil apfs listSnapshots "$SNAPSHOT_VOLUME" 2>/dev/null | grep -Fqi "$SNAPSHOT_UUID"; then
    log "Snapshot UUID was not found on $SNAPSHOT_VOLUME."
    exit 20
  fi
  if ! confirm "Delete snapshot $SNAPSHOT_UUID from $SNAPSHOT_VOLUME? This cannot be undone."; then log "Action cancelled."; exit 10; fi
  run_action "Deleting APFS snapshot $SNAPSHOT_UUID" /usr/sbin/diskutil apfs deleteSnapshot "$SNAPSHOT_VOLUME" -uuid "$SNAPSHOT_UUID" || true
fi

collect_state "$VERIFY"
if [ "$FAILURES" -gt 0 ]; then log "Operation completed with $FAILURES warning(s)."; exit 20; fi
log "Operation completed successfully. Actions performed: $ACTIONS"
exit 0
