#!/bin/bash
set -u

HOURS=24
OUTPUT_DIR=""
usage(){ echo "Usage: apfs_disk_snapshot_analyzer.sh [--hours N] [--output DIR]"; }
while [ "$#" -gt 0 ]; do case "$1" in --hours) HOURS="${2:-24}"; shift 2;; --output) OUTPUT_DIR="${2:-}"; shift 2;; -h|--help) usage; exit 0;; *) echo "Unknown argument: $1" >&2; exit 2;; esac; done
case "$HOURS" in ''|*[!0-9]*) echo "--hours must be numeric" >&2; exit 2;; esac
[ "$(uname -s)" = Darwin ] || { echo "This tool must run on macOS." >&2; exit 1; }
STAMP=$(date +%Y%m%d_%H%M%S); OUTPUT_DIR="${OUTPUT_DIR:-./apfs-analysis-$STAMP}"; mkdir -p "$OUTPUT_DIR"
REPORT="$OUTPUT_DIR/apfs-report.txt"; CSV="$OUTPUT_DIR/volumes.csv"; JSON="$OUTPUT_DIR/summary.json"; ERRORS="$OUTPUT_DIR/command-errors.log"; :>"$REPORT"; :>"$ERRORS"
echo 'device,mountpoint,filesystem,size_kib,used_kib,available_kib,capacity' > "$CSV"
section(){ t="$1"; shift; { printf '\n===== %s =====\n' "$t"; "$@"; } >>"$REPORT" 2>>"$ERRORS" || true; }
section "Metadata" /bin/bash -c 'date -u +%Y-%m-%dT%H:%M:%SZ; hostname; sw_vers; id'
section "Disk list" /usr/sbin/diskutil list
section "APFS containers" /usr/sbin/diskutil apfs list
section "Root volume" /usr/sbin/diskutil info /
section "Filesystem usage" /bin/df -kP
section "Local snapshots" /usr/bin/tmutil listlocalsnapshots /
section "APFS snapshots" /bin/bash -c 'diskutil apfs listsnapshots / 2>/dev/null || true'
section "Recent storage events" /bin/bash -c "/usr/bin/log show --last ${HOURS}h --style compact --predicate '(eventMessage CONTAINS[c] \"I/O error\") OR (eventMessage CONTAINS[c] \"APFS\") OR (eventMessage CONTAINS[c] \"filesystem\") OR (eventMessage CONTAINS[c] \"disk\")' 2>/dev/null | tail -n 3000"
/bin/df -kP | tail -n +2 | while read -r dev size used avail cap mount; do printf '"%s","%s","%s",%s,%s,%s,"%s"\n' "$dev" "$mount" "$(diskutil info "$mount" 2>/dev/null | awk -F: '/File System Personality/{gsub(/^ +/,"",$2); print $2; exit}')" "$size" "$used" "$avail" "$cap" >> "$CSV"; done
ROOT_USED=$(/bin/df -kP / | awk 'NR==2{gsub("%","",$5); print $5}')
SNAPSHOTS=$(/usr/bin/tmutil listlocalsnapshots / 2>/dev/null | wc -l | tr -d ' ')
APFS_VOLUMES=$(/usr/sbin/diskutil apfs list 2>/dev/null | grep -c 'APFS Volume Disk' || true)
ENCRYPTED=$(/usr/sbin/diskutil apfs list 2>/dev/null | grep -c 'FileVault:.*Yes' || true)
OVERALL="Healthy"; [ "${ROOT_USED:-0}" -ge 90 ] && OVERALL="Attention required"
cat > "$JSON" <<EOF
{"collected_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","hostname":"$(hostname)","apfs_volumes":$APFS_VOLUMES,"encrypted_volumes":$ENCRYPTED,"local_snapshots":$SNAPSHOTS,"root_used_percent":${ROOT_USED:-0},"overall_status":"$OVERALL"}
EOF
printf '\nAPFS analysis completed: %s\n' "$OUTPUT_DIR" | tee -a "$REPORT"
