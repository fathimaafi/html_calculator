# iOS Calculator — GCP Deployment

A static iOS-style calculator web app containerized with Docker and deployed to a GCP VM using GitHub Actions CI/CD, Terraform infrastructure management, and Cloudflare DNS.

**Live URL:** https://userpage.beework.in

---

## Table of Contents

- [Application Overview](#application-overview)
- [Project Structure](#project-structure)
- [GitHub Actions Workflow](#github-actions-workflow)
- [Docker Containerization](#docker-containerization)
- [Terraform Infrastructure](#terraform-infrastructure)
- [Nginx Configuration](#nginx-configuration)
- [Cloudflare DNS Settings](#cloudflare-dns-settings)
- [GitHub Secrets Setup](#github-secrets-setup)
- [How Deployment Works End to End](#how-deployment-works-end-to-end)

---

## Application Overview

A fully client-side iOS-style calculator built with plain HTML, CSS, and JavaScript. No frameworks or dependencies — single `index.html` file.

Features:
- Basic arithmetic: addition, subtraction, multiplication, division
- Chained operations (e.g. `1 + 2 + 3 =`)
- Expression preview line showing the full equation as you type
- iOS-style UI with orange operator buttons, gray function buttons, dark number buttons
- Auto-scaling display for long numbers
- Percent and sign toggle buttons

---

## Project Structure

```
userpage/
├── index.html                        # Calculator app (single file)
├── Dockerfile                        # Docker image definition
├── nginx.conf                        # Nginx config for the container
├── .dockerignore                     # Files excluded from Docker build
├── .github/
│   └── workflows/
│       └── deploy.yml                # GitHub Actions CI/CD pipeline
└── terraform/
    ├── main.tf                       # GCP VM infrastructure definition
    ├── terraform.tfvars              # Variable values (project, region, zone)
    └── .terraform.lock.hcl          # Provider version lock file
```

---

## GitHub Actions Workflow

File: `.github/workflows/deploy.yml`

Triggers automatically on every push to the `main` branch.

### Steps

**Step 1 — Checkout Source Code**
Downloads the latest code from the repository into the GitHub Actions runner.

**Step 2 — Copy Files to VM**
Uses `appleboy/scp-action` to securely copy `index.html`, `Dockerfile`, and `nginx.conf` to `/tmp/calculator/` on the GCP VM via SCP over SSH.

- `strip_components: 1` ensures files land directly in `/tmp/calculator/` without nested workspace paths
- `overwrite: true` replaces existing files on every push

**Step 3 — Deploy to VM**
Uses `appleboy/ssh-action` to SSH into the VM and run the deployment script:

- Always moves the latest `index.html` to `/var/www/html/` (the web root mounted into the container)
- Checks if the Docker container is already running:
  - **First run:** builds the Docker image and starts the container on port 8080
  - **Subsequent runs:** skips Docker build entirely — the volume mount picks up the updated `index.html` instantly with no restart needed

### Required GitHub Secrets

| Secret | Description |
|---|---|
| `VM_HOST` | Public IP address of the GCP VM |
| `VM_USER` | SSH username on the VM |
| `VM_SSH_KEY` | Private SSH key for authentication |

---

## Docker Containerization

### Dockerfile

```dockerfile
FROM nginx:alpine

RUN rm -rf /usr/share/nginx/html/*

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
```

- Base image: `nginx:alpine` — lightweight (~25MB)
- Copies custom `nginx.conf` to override the default nginx configuration
- Copies `index.html` into the web root
- Exposes port 8080 (VM nginx handles port 80/443 externally)

### Running the Container

```bash
docker run -d \
  --name calculator \
  --restart always \
  -p 8080:8080 \
  -v /var/www/html:/usr/share/nginx/html:ro \
  calculator:latest
```

- `--restart always` — container auto-starts if the VM reboots
- `-p 8080:8080` — maps container port 8080 to VM port 8080
- `-v /var/www/html:/usr/share/nginx/html:ro` — mounts the VM web root as read-only into the container, so file updates are reflected instantly without rebuilding the image

### .dockerignore

Excludes unnecessary files from the Docker build context:
```
.github/
terraform/
gh_deploy_key
gh_deploy_key.pub
```

---

## Terraform Infrastructure

File: `terraform/main.tf`

Manages the GCP VM using Terraform. The VM already existed and was imported into Terraform state using the `import` block.

### Variables

| Variable | Default | Description |
|---|---|---|
| `gcp_project` | — | GCP project ID |
| `gcp_region` | `us-central1` | GCP region |
| `gcp_zone` | `us-central1-f` | GCP zone |

### VM Configuration

- **Name:** `firstvmmachinedockernode`
- **Machine type:** `e2-medium`
- **OS:** Ubuntu 24.04 LTS (Minimal)
- **Network:** Default VPC with public IP
- **Tags:** `http-server`, `https-server` — required for GCP firewall rules to allow ports 80 and 443

### Importing Existing VM

The `import` block links the existing GCP VM to Terraform state without recreating it:

```hcl
import {
  to = google_compute_instance.existing_web_server
  id = "projects/<project>/zones/<zone>/instances/firstvmmachinedockernode"
}
```

### Commands

```bash
# Authenticate with GCP
gcloud auth application-default login

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply changes
terraform apply
```

### terraform.tfvars

```hcl
gcp_project = "<your-project-id>"
gcp_region  = "us-central1"
gcp_zone    = "us-central1-f"
```

---

## Nginx Configuration

Two nginx configurations are involved:

### 1. Container Nginx — `nginx.conf`

Runs inside the Docker container, listens on port 8080:

```nginx
server {
    listen 8080;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    gzip on;
    gzip_types text/html text/css application/javascript;
}
```

### 2. VM Nginx — `/etc/nginx/sites-available/userpage.beework.in`

Runs on the VM, handles SSL termination and proxies traffic to the Docker container:

```nginx
server {
    server_name userpage.beework.in www.userpage.beework.in;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    listen [::]:443 ssl ipv6only=on; # managed by Certbot
    listen 443 ssl;                  # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/userpage.beework.in/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/userpage.beework.in/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
}

server {
    if ($host = www.userpage.beework.in) {
        return 301 https://$host$request_uri;
    }

    if ($host = userpage.beework.in) {
        return 301 https://$host$request_uri;
    }

    listen 0.0.0.0:80 default_server;
    listen [::]:80 default_server;
    server_name userpage.beework.in www.userpage.beework.in;
}
```

SSL certificate is managed by **Certbot (Let's Encrypt)**.

To renew the certificate:
```bash
sudo certbot renew
```

---

## Cloudflare DNS Settings

Cloudflare sits in front of the GCP VM and provides DNS, DDoS protection, and CDN.

### DNS Records

| Type | Name | Value | Proxy |
|---|---|---|---|
| `A` | `userpage` | `<GCP VM public IP>` | Proxied (orange cloud) |
| `A` | `www.userpage` | `<GCP VM public IP>` | Proxied (orange cloud) |

### Important Settings

- **Proxy status:** Set to **Proxied** (orange cloud) — routes traffic through Cloudflare's network
- **SSL/TLS mode:** Set to **Full (strict)** in Cloudflare dashboard → SSL/TLS → Overview
  - `Full` — Cloudflare encrypts to your VM but doesn't verify the cert
  - `Full (strict)` — requires a valid SSL cert on the VM (use this since Certbot is configured)
- **Always Use HTTPS:** Enable under SSL/TLS → Edge Certificates → Always Use HTTPS

### How Traffic Flows

```
User → Cloudflare (DNS + CDN) → GCP VM public IP
                                  → VM Nginx (port 443, SSL)
                                    → Docker container (port 8080)
                                      → index.html (from /var/www/html volume)
```

---

## GitHub Secrets Setup

Go to your GitHub repository → Settings → Secrets and variables → Actions → New repository secret.

| Secret | How to get it |
|---|---|
| `VM_HOST` | GCP Console → Compute Engine → VM instances → External IP |
| `VM_USER` | Your SSH username on the VM |
| `VM_SSH_KEY` | Contents of your private SSH key file |

To generate a new SSH key pair for deployments:
```bash
ssh-keygen -t rsa -b 4096 -C "github-actions-deploy" -f gh_deploy_key
# Add gh_deploy_key.pub to VM metadata in GCP Console
# Add gh_deploy_key contents to VM_SSH_KEY secret in GitHub
```

---

## How Deployment Works End to End

```
git push origin main
        │
        ▼
GitHub Actions triggered
        │
        ├─ SCP: copies index.html + Dockerfile + nginx.conf → /tmp/calculator/ on VM
        │
        └─ SSH:
            ├─ mv /tmp/calculator/index.html → /var/www/html/index.html
            │
            ├─ [First deploy only]
            │   ├─ docker build -t calculator:latest .
            │   └─ docker run -p 8080:8080 -v /var/www/html:/usr/share/nginx/html:ro
            │
            └─ [Subsequent deploys]
                └─ Container already running, file updated via volume mount ✓
```

Every push to `main` updates the live site at https://userpage.beework.in within seconds.
