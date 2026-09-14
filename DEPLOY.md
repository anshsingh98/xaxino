# XAXINO — Render Deployment Guide

The project has been restructured from the original CodeCanyon layout into a standard Laravel layout so it can be deployed to Render via Docker.

## New structure

```
├── app/                  # Laravel application code (was Files/core/app)
├── bootstrap/
├── config/
├── database/
│   └── xaxino_mysql.sql  # Full DB dump (was Files/install_backup/database.sql)
├── routes/
├── resources/
├── storage/
├── temp/
├── public/               # Web root (was Files/)
│   ├── index.php         # Standard Laravel front controller
│   ├── assets/
│   └── .htaccess
├── docker/
│   ├── nginx.conf
│   └── start.sh          # Boot script: env setup, DB import, caches, nginx+fpm
├── Dockerfile            # PHP 8.3-fpm + nginx + composer
├── render.yaml           # Render Blueprint
├── composer.json / .lock
└── .env.example
```

## Deploy steps

1. Push this repo to GitHub.
2. On Render: **New → Blueprint** (auto-reads `render.yaml`).
3. The Blueprint provisions **two services**:
   - `xaxino-mysql` — private MySQL 8.0 service with the schema auto-imported on first boot.
   - `xaxino` — the Laravel app (Docker, PHP 8.3 + nginx), connected to MySQL automatically via `fromService` env links.
4. Set only these two prompts when applying the Blueprint:
   - `APP_URL=https://xaxino-xxxx.onrender.com` (your Render URL)
5. The boot script (`docker/start.sh`) automatically:
   - syncs all env vars into `.env` and generates `APP_KEY`
   - waits for MySQL and imports `database/xaxino_mysql.sql` on first boot
   - runs migrations, `storage:link`, caches config/routes/views
   - starts php-fpm + nginx on port 8000.

## Notes

- PHP 8.3 is required (enforced by `composer.json`).
- Health check endpoint: `/up`.
- Uploads live in `public/uploads` / `storage` — Render's disk is ephemeral; attach a Render Disk or S3-compatible storage for persistent files if needed.
- The original `Documentation/` folder is deployment docs only; it is excluded from the Docker image.
