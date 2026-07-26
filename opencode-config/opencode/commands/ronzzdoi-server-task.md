---
description: Run a task on ronzz-linux-server-2
agent: copilot
---

Perform the following task on ronzz-linux-server-2: $1

## SSH access

```bash
ssh ronzz-linux-server-2   # HostName 158.178.193.231, user ubuntu, key ~/Syncthing/oci/ssh-key-2025-11-27.key
```

The `ubuntu` user has passwordless sudo.

## Server context

| Item | Location |
|------|----------|
| **ronzzdoi API** (FastAPI) | `/opt/ronzzdoi/` — systemd `ronzzdoi.service`, runs as `ronzz` user |
| **ronzzdoi-web** (Astro SSR) | `/opt/ronzzdoi-public-web/` — systemd `ronzzdoi-web.service`, runs as `ronzz` user |
| **ronzzdoi data** | `/opt/ronzzdoi/data/` (SQLite WAL) |
| **nginx configs** | `/etc/nginx/sites-available/doi.ronzz.org.conf`, `doi-api.ronzz.org.conf` |
| **Let's Encrypt certs** | `/etc/letsencrypt/{doi.ronzz.org,doi-api.ronzz.org,api.doi.ronzz.org}/` |
| **Dependency repos** | `/opt/lightercore/`, `/opt/lighterauth/`, `/opt/lightersearch/` |
| **Systemd logs** | `sudo journalctl -u ronzzdoi -f` / `sudo journalctl -u ronzzdoi-web -f` |
| **Cloudflare zone** | Zone ID `f4aead805ba816ad82a3d53d267678fd`, token in sudo crontab |

## Common operations

```bash
# Restart services
sudo systemctl restart ronzzdoi
sudo systemctl restart ronzzdoi-web

# Check status
sudo systemctl status ronzzdoi --no-pager
sudo systemctl status ronzzdoi-web --no-pager

# Deploy latest code (sync + restart)
sudo -u ronzz git -C /opt/ronzzdoi pull origin main
sudo -u ronzz HOME=/opt/ronzzdoi sh -c 'cd /opt/ronzzdoi && uv sync --extra public --no-dev'
sudo systemctl restart ronzzdoi

# Web deploy
sudo -u ronzz git -C /opt/ronzzdoi-public-web pull origin main
sudo -u ronzz HOME=/opt/ronzzdoi-public-web sh -c 'cd /opt/ronzzdoi-public-web && npm ci && npm run build'
sudo systemctl restart ronzzdoi-web

# Run CLI directly on server
sudo -u ronzz HOME=/opt/ronzzdoi /opt/ronzzdoi/.venv/bin/ronzzdoi --server http://127.0.0.1:8012 --api-key "<key>" doi search

# Tail nginx logs
sudo tail -f /var/log/nginx/ronzzdoi-api.access.log
sudo tail -f /var/log/nginx/ronzzdoi-web.access.log
```

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
