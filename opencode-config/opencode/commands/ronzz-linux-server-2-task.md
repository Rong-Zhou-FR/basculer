---
description: Perform any admin task on ronzz-linux-server-2 (general server)
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

| Service | Type | Location / Notes |
|---------|------|------------------|
| **midiverse** (NestJS backend + Nuxt frontend) | systemd/PM2 | `/var/www/midiverse-deployment/` |
| **ronzzdoi API** (FastAPI) | systemd `ronzzdoi.service` | `127.0.0.1:8012`, runs as `ronzz` |
| **ronzzdoi-public-web** (Astro SSR) | systemd `ronzzdoi-web.service` | `127.0.0.1:4321`, runs as `ronzz` |
| **nginx** | systemd | Proxies `doi.ronzz.org` + `doi-api.ronzz.org` |
| **MySQL** | systemd `mysql.service` | Legacy, localhost only |
| **Docker** | systemd `docker.service` | No active containers currently |

### Removed (cleaned up Jul 2026)

- 3× Ghost blogs (kodo, midimonde, third) — files + MySQL DBs removed
- ronzz-org Docker stack (Caddy + SvelteKit + Postgres) — abandoned, all removed

## Key paths

| Path | Purpose |
|------|---------|
| `/opt/ronzzdoi/` | ronzzdoi API repo + `.venv` |
| `/opt/ronzzdoi/data/` | SQLite data |
| `/opt/ronzzdoi-public-web/` | Astro frontend repo + `dist/` |
| `/opt/lightercore/`, `/opt/lighterauth/`, `/opt/lightersearch/` | Python deps |
| `/var/www/midiverse-deployment/` | midiverse project |
| `/etc/nginx/sites-available/` | nginx configs |
| `/etc/letsencrypt/` | SSL certs (acme.sh) |
| `/var/log/nginx/` | nginx logs |

## Common operations

```bash
# System
htop
df -h /
free -h
journalctl -xe -n 30 | grep -i error

# Services
sudo systemctl status <service> --no-pager
sudo journalctl -u <service> -f
sudo systemctl restart <service>

# nginx
sudo nginx -t && sudo nginx -s reload
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
