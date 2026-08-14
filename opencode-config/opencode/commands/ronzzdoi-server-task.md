---
description: Run a task on ronzz-linux-server-2
agent: copilot
---

Perform the following task on ronzz-linux-server-2: $1

> **Server info** (SSH, specs, services, paths, generic operations) lives in the single
> source of truth **`~/Syncthing/oci/ronzz-linux-server-2.md`** — read it before acting.

## SSH access

```bash
ssh ronzz-linux-server-2   
```

The `ubuntu` user has **passwordless sudo**.

## ronzzdoi specifics

Service paths, systemd units (`ronzzdoi.service`, `ronzzdoi-web.service`), and deploy
commands for ronzzdoi / ronzzdoi-web live in the source of truth (Services, Key paths,
Common operations sections).

Extra ronzzdoi-only operations:

```bash
# Run CLI directly on server
sudo -u ronzz HOME=/opt/ronzzdoi /opt/ronzzdoi/.venv/bin/ronzzdoi --server http://127.0.0.1:8012 --api-key "<key>" doi search

# Tail ronzzdoi nginx logs
sudo tail -f /var/log/nginx/ronzzdoi-api.access.log
sudo tail -f /var/log/nginx/ronzzdoi-web.access.log
```

Cloudflare: zone `f4aead805ba816ad82a3d53d267678fd`, token in sudo crontab.

## Deployment (GitHub Actions)

Both repos auto-deploy on push to `main`:
- `Ron-RONZZ-org/ronzzdoi` → `.github/workflows/deploy.yml`
- `Ron-RONZZ-org/ronzzdoi-public-web` → `.github/workflows/deploy.yml`

The deploy key is stored as GitHub secret `DEPLOY_SSH_KEY` in both repos.

## Domains

| Domain | Purpose | Cloudflare |
|--------|---------|------------|
| `doi.ronzz.org` | Public web frontend | proxied, Full strict TLS |
| `doi-api.ronzz.org` | Public CLI API endpoint | proxied, Full strict TLS |
