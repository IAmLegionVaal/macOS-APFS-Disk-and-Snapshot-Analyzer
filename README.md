# macOS APFS Disk and Snapshot Analyzer

A read-only Bash toolkit for collecting APFS container, volume, snapshot, encryption, capacity, and filesystem health evidence.

## Usage

```bash
chmod +x src/apfs_disk_snapshot_analyzer.sh
sudo ./src/apfs_disk_snapshot_analyzer.sh
```

## Checks performed

- Physical disks, APFS containers, and volumes
- Volume roles, mount points, encryption, capacity, and free space
- Local Time Machine and APFS snapshots
- SMART and disk information where available
- Recent storage, filesystem, and I/O events
- Text, CSV, and JSON reports

## Safety

The script never repairs, verifies, mounts, unmounts, deletes snapshots, resizes containers, or modifies disks.

## Author

Dewald Pretorius — L2 IT Support Engineer
