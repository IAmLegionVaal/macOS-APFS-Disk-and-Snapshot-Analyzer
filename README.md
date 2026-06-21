# macOS APFS Disk and Snapshot Analyzer

A macOS support toolkit for collecting APFS storage evidence and applying selected volume or snapshot repairs.

## Diagnostic script

```bash
chmod +x src/apfs_disk_snapshot_analyzer.sh
sudo ./src/apfs_disk_snapshot_analyzer.sh
```

The diagnostic script reports physical disks, APFS containers and volumes, roles, mount points, encryption, capacity, snapshots, SMART information and recent storage events.

## Repair script

Verify one volume:

```bash
chmod +x src/apfs_disk_repair.sh
sudo ./src/apfs_disk_repair.sh --verify-volume /
```

Run First Aid on one volume:

```bash
sudo ./src/apfs_disk_repair.sh --repair-volume /
```

Delete one selected APFS snapshot:

```bash
sudo ./src/apfs_disk_repair.sh \
  --delete-snapshot / \
  12345678-1234-1234-1234-123456789ABC
```

Preview any action with `--dry-run`.

## What the repair does

- Verifies one selected volume.
- Runs `diskutil repairVolume` on one selected volume.
- Can delete one explicitly selected APFS snapshot by UUID.
- Captures before-and-after APFS state.
- Supports confirmation prompts, dry-run, logs and clear exit codes.

## Safety and limitations

Volume repair can interrupt applications using the selected volume. Snapshot deletion is irreversible and requires an exact UUID plus confirmation. The tool does not resize containers, erase disks or automatically delete multiple snapshots. Hardware failure and unrepairable filesystem damage may require Recovery mode or storage replacement.

## Author

Dewald Pretorius — L2 IT Support Engineer
