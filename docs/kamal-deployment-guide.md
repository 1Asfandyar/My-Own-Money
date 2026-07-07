# Kamal Deployment Guide

This guide covers deploying RupeeRally to any environment using Kamal 2. Two environments are supported out of the box: **production** and **development** (staging).

---

## Prerequisites

- Kamal 2 installed: `gem install kamal` (already in the Gemfile dev group)
- Docker installed and running on your local machine
- A Linux server (Ubuntu 22.04+ recommended) with SSH access as root or a sudo user
- A domain name pointed at your server's IP
- A container registry account — this guide uses [GitHub Container Registry (ghcr.io)](https://ghcr.io), which is free

---

## File Structure

```
config/
  deploy.yml              # Shared base config (committed)
  deploy.production.yml   # Production overrides (committed)
  deploy.development.yml  # Staging/dev overrides (committed)

.kamal/
  secrets.production      # Sources .env.production (gitignored)
  secrets.development     # Sources .env.development (gitignored)
  secrets.production.example   # Template (committed)
  secrets.development.example  # Template (committed)

.env.production           # All production secrets (gitignored)
.env.development          # All staging secrets (gitignored)
.env.production.example   # Template (committed)
.env.development.example  # Template (committed)

.env                      # Local development only — NOT used by Kamal
```

---

## Step 1 — Prepare your server

1. Spin up a fresh Ubuntu 22.04+ VPS (DigitalOcean, Hetzner, Vultr, etc.)
2. SSH in as root and ensure Docker is not already installed (Kamal installs it)
3. Point your domain (or subdomain for staging) at the server's IP via your DNS provider
4. Make sure port 80 and 443 are open (Kamal's proxy needs them for TLS)

---

## Step 2 — Create a GitHub Container Registry token

1. Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click **Generate new token (classic)**
3. Select scopes: `write:packages`, `read:packages`, `delete:packages`
4. Copy the token — you'll paste it into `.env.production` / `.env.development`

---

## Step 3 — Fill in the deploy config placeholders

Open [config/deploy.yml](../config/deploy.yml) and update:
```yaml
image: ghcr.io/<your-github-username>/rupeerally
```

Open [config/deploy.production.yml](../config/deploy.production.yml) and update:
```yaml
servers:
  web:
    - 1.2.3.4            # your production server IP
  job:
    hosts:
      - 1.2.3.4

env:
  clear:
    CORS_ALLOWED_ORIGINS: "https://yourdomain.com"

proxy:
  host: yourdomain.com

accessories:
  db:
    host: 1.2.3.4
```

Do the same for [config/deploy.development.yml](../config/deploy.development.yml) with your staging server IP and staging subdomain.

---

## Step 4 — Set up your .env files

### For production

```bash
cp .env.production.example .env.production
```

Edit `.env.production` and fill in every value:

| Variable | Where to get it |
|---|---|
| `KAMAL_REGISTRY_USERNAME` | Your GitHub username |
| `KAMAL_REGISTRY_PASSWORD` | Token from Step 2 |
| `RAILS_MASTER_KEY` | Contents of `config/master.key` (one line, no quotes) |
| `DATABASE_URL` | `postgres://mom_user:yourpassword@127.0.0.1:5432/mom_production` |
| `POSTGRES_USER` | Must match `DATABASE_URL` username |
| `POSTGRES_PASSWORD` | Must match `DATABASE_URL` password |
| `GOOGLE_CLIENT_ID` | From Google Cloud Console → OAuth 2.0 Client IDs |
| `GOOGLE_CLIENT_SECRET` | From Google Cloud Console |

### For development/staging

```bash
cp .env.development.example .env.development
```

Fill in the same variables with staging-specific values. Use a different database name (`mom_development`) and a separate Google OAuth client if possible.

---

## Step 5 — Set up Kamal secrets files

These files tell Kamal where to find your secrets. They simply source the `.env.*` files you created above.

```bash
cp .kamal/secrets.production.example .kamal/secrets.production
cp .kamal/secrets.development.example .kamal/secrets.development
```

No edits needed — they already contain `. .env.production` and `. .env.development` respectively.

---

## Step 6 — First-time setup (provision server)

Run this **once per environment** to install Docker, configure kamal-proxy, and start all accessories (Postgres):

```bash
# Production
kamal setup -d production

# Staging / development
kamal setup -d development
```

This command:
1. SSHes into your server
2. Installs Docker if missing
3. Starts `kamal-proxy` (handles TLS + routing)
4. Starts the Postgres accessory container
5. Builds and pushes your Docker image
6. Deploys the app for the first time
7. Runs `db:prepare` via the entrypoint (creates DB + runs migrations)

---

## Step 7 — Deploy (subsequent deploys)

After the first setup, use `kamal deploy` for all future deploys:

```bash
# Deploy to production
kamal deploy -d production

# Deploy to staging
kamal deploy -d development
```

This does a **zero-downtime rolling deploy**: builds a new image, starts the new container, health-checks it at `/up`, then cuts over traffic.

---

## Common Commands

### Check app status
```bash
kamal details -d production
```

### View live logs
```bash
kamal app logs -d production
kamal app logs -d production --follow   # tail -f equivalent
```

### Run a Rails console on the server
```bash
kamal app exec -d production --interactive "bin/rails console"
```

### Run a one-off command (e.g. db:seed)
```bash
kamal app exec -d production "bin/rails db:seed"
```

### Roll back to the previous deploy
```bash
kamal rollback -d production
```

### Restart the app
```bash
kamal app restart -d production
```

### SSH into the server
```bash
kamal server exec -d production bash
```

### Push updated env secrets without redeploying
```bash
kamal env push -d production
kamal app restart -d production   # restart to pick up the new env
```

### Accessory (Postgres) commands
```bash
# View Postgres logs
kamal accessory logs db -d production

# Restart Postgres
kamal accessory restart db -d production

# Open a psql shell
kamal accessory exec db -d production --interactive "psql -U mom_user -d mom_production"
```

---

## ENV Variables Reference

### Variables in config/deploy.*.yml → env.clear (not secret, committed)

| Variable | Purpose |
|---|---|
| `RAILS_LOG_TO_STDOUT` | Sends logs to Docker stdout (always true) |
| `RAILS_SERVE_STATIC_FILES` | Serves assets directly from the container |
| `WEB_CONCURRENCY` | Number of Puma worker processes |
| `RAILS_MAX_THREADS` | Puma threads per worker |
| `RAILS_LOG_LEVEL` | `info` for production, `debug` for staging |
| `CORS_ALLOWED_ORIGINS` | Comma-separated list of allowed frontend origins |

### Variables in config/deploy.*.yml → env.secret (pulled from .env.*)

| Variable | Purpose |
|---|---|
| `RAILS_MASTER_KEY` | Decrypts `config/credentials.yml.enc` |
| `DATABASE_URL` | Full Postgres connection string |
| `POSTGRES_USER` | Postgres superuser for the accessory container |
| `POSTGRES_PASSWORD` | Postgres password for the accessory container |
| `GOOGLE_CLIENT_ID` | Google OAuth client ID |
| `GOOGLE_CLIENT_SECRET` | Google OAuth client secret |
| `KAMAL_REGISTRY_USERNAME` | GitHub username for ghcr.io |
| `KAMAL_REGISTRY_PASSWORD` | GitHub PAT with `write:packages` scope |

---

## How secrets flow at deploy time

```
.env.production
      │
      └─ sourced by .kamal/secrets.production
                          │
                          └─ read by Kamal at deploy time
                                      │
                                      └─ injected into the Docker container
                                         as environment variables listed in
                                         config/deploy.production.yml → env.secret
```

The `.env.production` file never touches the server or the Docker image. Kamal reads it locally and injects the variables as Docker secrets, which the container receives as environment variables at runtime.

---

## GitHub Actions CI/CD (Manual Deploy)

The workflow at [.github/workflows/deploy.yml](../.github/workflows/deploy.yml) lets you deploy to either environment directly from GitHub without touching secrets on your local machine.

### How secrets flow in CI

```
GitHub Environment secrets
        │
        └─ written to .env.<environment> by the workflow
                          │
                          └─ sourced by .kamal/secrets.<environment>
                                          │
                                          └─ read by Kamal → injected into container
```

The `.env.*` file is written inside the ephemeral runner and never persisted. The `.kamal/secrets.*` file already exists as a committed example that just does `. .env.<environment>` — the workflow copies it as-is.

---

### Step 1 — Create GitHub Environments

Go to your repo → **Settings → Environments** and create two environments:

- `production`
- `development`

Optionally add **required reviewers** to `production` so every deploy needs approval.

---

### Step 2 — Add secrets to each environment

For each environment, add the following secrets under **Settings → Environments → \<env\> → Environment secrets**:

| Secret | Value |
|---|---|
| `SSH_PRIVATE_KEY` | Contents of your local `~/.ssh/id_rsa` (the key authorized on the server) |
| `SSH_KNOWN_HOSTS` | Output of `ssh-keyscan -H <server-ip>` run locally |
| `KAMAL_REGISTRY_USERNAME` | Your GitHub username |
| `KAMAL_REGISTRY_PASSWORD` | GitHub PAT with `write:packages` scope |
| `RAILS_MASTER_KEY` | Contents of `config/master.key` (one line, no quotes) |
| `DATABASE_URL` | `postgres://mom_user:password@127.0.0.1:5432/mom_<env>` |
| `POSTGRES_USER` | Must match `DATABASE_URL` username |
| `POSTGRES_PASSWORD` | Must match `DATABASE_URL` password |
| `GOOGLE_CLIENT_ID` | From Google Cloud Console |
| `GOOGLE_CLIENT_SECRET` | From Google Cloud Console |

> **Tip — generate SSH_KNOWN_HOSTS:**
> ```bash
> ssh-keyscan -H <your-server-ip>
> ```
> Copy the full multi-line output as the secret value.

Each environment gets its **own copy** of every secret with environment-specific values (different server IPs, different DB passwords, etc.).

---

### Step 3 — Trigger a deploy

Go to **Actions → Deploy → Run workflow**, pick the environment, and click **Run workflow**.

The workflow:
1. Checks out the repo
2. Installs gems (cached)
3. Loads your SSH key and known hosts into `~/.ssh`
4. Writes `.env.<environment>` from the GitHub Environment secrets
5. Copies `.kamal/secrets.<environment>.example` → `.kamal/secrets.<environment>`
6. Runs `kamal deploy -d <environment>`

---

### Why GitHub Environments instead of repository secrets?

- **Scoping** — production and development secrets are stored separately; no risk of accidentally deploying staging credentials to production.
- **Approval gates** — GitHub lets you require manual approval before any job in the `production` environment runs.
- **Audit trail** — every deploy shows which environment was targeted, who triggered it, and when.

---

### First-time setup via CI

`kamal deploy` assumes the server is already provisioned (Docker installed, kamal-proxy running, Postgres accessory started). If this is a brand-new server, run the first-time setup locally:

```bash
kamal setup -d production   # or -d development
```

After that, all subsequent deploys can go through the GitHub Actions workflow.

---

## Troubleshooting

### "Permission denied" when SSHing
Ensure your local SSH key is in `~/.ssh/authorized_keys` on the server. Test with `ssh root@your-server-ip`.

### "Cannot connect to registry"
Check that `KAMAL_REGISTRY_USERNAME` and `KAMAL_REGISTRY_PASSWORD` in `.env.production` are correct and the token has `write:packages` scope.

### App fails health check after deploy
```bash
kamal app logs -d production    # check for startup errors
kamal app exec -d production --interactive "bin/rails db:migrate:status"
```

### TLS / SSL not provisioning
- Confirm your domain's DNS A record points to the correct server IP
- Port 80 must be open for Let's Encrypt's HTTP-01 challenge
- Check kamal-proxy logs: `kamal proxy logs -d production`

### Database connection refused
Ensure `DATABASE_URL` host is `127.0.0.1` (not `localhost`) — the Postgres accessory binds to `127.0.0.1:5432` on the host, and the app container reaches it via host networking.
