---
description: Perform a task on ronzz-linux-server-2 (general server admin)
agent: copilot
---

# ronzz-linux-server-2: $1

## SSH access

```bash
ssh ronzz-linux-server-2   # HostName 158.178.193.231, user ubuntu, key ~/Syncthing/oci/ssh-key-2025-11-27.key
```

The `ubuntu` user has **passwordless sudo** and is in the `docker` group.

| Detail | Value |
|--------|-------|
| Host | `158.178.193.231` (OCI, Paris region) |
| OS | Ubuntu 24.04.3 LTS (aarch64) |
| CPU | 4× Neoverse-N1 |
| RAM | 11 GiB |
| Disk | 45 GB (22G used, 23G free) |
| Uptime | ~85 days |

## Services on this server

### Active

| Service | Type | Status |
|---------|------|--------|
| **midiverse** (NestJS backend + Nuxt frontend) | systemd/PM2 | Running — `/var/www/midiverse-deployment/` |
| **ronzzdoi API** (FastAPI) | systemd `ronzzdoi.service` | Running on `127.0.0.1:8012` as `ronzz` user |
| **ronzzdoi-public-web** (Astro SSR) | systemd `ronzzdoi-web.service` | Running on `127.0.0.1:4321` as `ronzz` user |
| **nginx** | systemd | Proxies `doi.ronzz.org` + `doi-api.ronzz.org` |
| **MySQL** | systemd `mysql.service` | Legacy database server |
| **Docker** | systemd `docker.service` | No active containers currently |

### Removed (cleaned up Jul 2026)

| What | Why |
|------|-----|
| 3× Ghost blogs (kodo, midimonde, third) | Abandoned, files + MySQL DBs removed |
| ronzz-org Docker stack (Caddy + SvelteKit + Postgres) | Abandoned project, compose + volumes removed |

## Key paths

| Path | Purpose |
|------|---------|
| `/opt/ronzzdoi/` | ronzzdoi API repo + `.venv` |
| `/opt/ronzzdoi/data/` | SQLite data |
| `/opt/ronzzdoi-public-web/` | Astro frontend repo + `dist/` |
| `/opt/lightercore/`, `/opt/lighterauth/`, `/opt/lightersearch/` | Python dependency repos |
| `/var/www/midiverse-deployment/` | midiverse project (NestJS) |
| `/etc/nginx/sites-available/` | nginx configs |
| `/etc/letsencrypt/` | SSL certs (Let's Encrypt via acme.sh) |
| `/var/log/nginx/` | nginx logs |

## Common operations

```bash
# Check system
htop
df -h /
free -h
journalctl -xe -n 30

# Restart nginx
sudo nginx -t && sudo nginx -s reload

# Tail logs
sudo journalctl -u <service> -f
sudo tail -f /var/log/nginx/*.log

# Deploy ronzzdoi
sudo -u ronzz git -C /opt/ronzzdoi pull origin main
sudo -u ronzz HOME=/opt/ronzzdoi sh -c 'cd /opt/ronzzdoi && uv sync --extra public --no-dev'
sudo systemctl restart ronzzdoi

# Deploy ronzzdoi-web
sudo -u ronzz git -C /opt/ronzzdoi-public-web pull origin main
sudo -u ronzz HOME=/opt/ronzzdoi-public-web sh -c 'cd /opt/ronzzdoi-public-web && npm ci && npm run build'
sudo systemctl restart ronzzdoi-web
```

## Domains

| Domain | Target | TLS |
|--------|--------|-----|
| `doi.ronzz.org` | ronzzdoi public web (Astro) | Cloudflare Full strict |
| `doi-api.ronzz.org` | ronzzdoi API (FastAPI) | Cloudflare Full strict |

## Deployment (GitHub Actions)

Both ronzzdoi repos auto-deploy on push to `main`:
- `Ron-RONZZ-org/ronzzdoi` → `.github/workflows/deploy.yml`
- `Ron-RONZZ-org/ronzzdoi-public-web` → `.github/workflows/deploy.yml`

Shared SSH deploy key stored as `DEPLOY_SSH_KEY` secret in both repos.
