---
description: Perform any admin task on ronzz-linux-server-2 (general server)
agent: copilot
---

# ronzz-linux-server-2

> **Single source of truth**: all server info (specs, services, paths, common operations,
> resource usage, backups) lives in **`~/Syncthing/oci/ronzz-linux-server-2.md`**.

## SSH access

```bash
ssh ronzz-linux-server-2
```

The `ubuntu` user has **passwordless sudo** and is in the `docker` group.

## Procedure

1. Read `~/Syncthing/oci/ronzz-linux-server-2.md` for the current server state.
2. SSH in and inspect (`htop`, `df -h /`, `free -h`, `journalctl -xe -n 30`).
3. Perform the task; verify; if the server state changed (services, paths, specs),
   update the source-of-truth file.

# TODO: $1
