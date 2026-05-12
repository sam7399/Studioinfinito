# Studioinfinito - Deployment Guide

## Architecture: Supabase + Hostinger + GitHub

```
┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
│   Hostinger         │     │   Hostinger          │     │   Supabase          │
│   (Frontend)        │────▶│   (Backend API)      │◄────│   (PostgreSQL DB)   │
│                     │     │                      │     │                     │
│ task.thestudio      │     │ api.thestudio        │     │ db.<ref>.supabase   │
│ infinito.com        │     │ infinito.com         │     │ .co:5432            │
│ Flutter Web (static)│     │ Node.js + Express    │     │ Free/Pro tier       │
└─────────────────────┘     └─────────────────────┘     └─────────────────────┘
        │                           │
        │                           │ GitHub → Auto-deploy
        ▼                           ▼
   CDN/Cloudflare           github.com/sam7399/
   (optional)               Studioinfinito
```

---

## 1. Supabase Database Setup

### Create Project:
1. Go to https://supabase.com → **New Project**
2. Choose a name, set a strong **database password**, select region
3. Wait for project to provision

### Get Connection Details:
1. Go to **Settings → Database → Connection string → URI**
2. Copy the individual fields for your `.env`:

```env
DBHOST=db.<your-project-ref>.supabase.co
DBNAME=postgres
DBUSER=postgres
DBPASS=<your-database-password>
DBPORT=5432
DBSSL=true
```

### Run Migrations:
```bash
cd backend
npm run db:migrate
```

Tables are also auto-created on server startup via `ensureSchema()`.

---

## 2. Hostinger Backend Deployment

### Option A: Node.js VPS Hosting
If you have a Hostinger VPS:

```bash
# SSH into your VPS
ssh user@your-vps-ip

# Clone the repo
git clone https://github.com/sam7399/Studioinfinito.git
cd Studioinfinito/backend

# Install dependencies
npm install --production

# Create .env with production values
nano .env
```

**Production `.env`:**
```env
NODE_ENV=production
PORT=26627

# Supabase Database
DBHOST=db.<your-project-ref>.supabase.co
DBNAME=postgres
DBUSER=postgres
DBPASS=<your-supabase-password>
DBPORT=5432
DBSSL=true

# JWT
JWT_SECRET=<generate-strong-secret-min-32-chars>
JWT_EXPIRES_IN=12h

# Email
EMAILHOST=smtp.gmail.com
EMAILPORT=587
EMAILSECURE=false
EMAILUSER=your-email@gmail.com
EMAILPASS=your-app-specific-password
EMAIL_FROM=TSI Task Manager <no-reply@thestudioinfinito.com>

# URLs
BASE_URL_API=https://api.thestudioinfinito.com
BASE_URL_APP=https://task.thestudioinfinito.com
CORS_ORIGINS=https://task.thestudioinfinito.com,https://www.thestudioinfinito.com

LOG_LEVEL=info
```

**Start with PM2 (recommended):**
```bash
npm install -g pm2
pm2 start src/server.js --name tsi-backend
pm2 save
pm2 startup
```

**Set up Nginx reverse proxy:**
```nginx
server {
    listen 80;
    server_name api.thestudioinfinito.com;

    location / {
        proxy_pass http://localhost:26627;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

**Enable SSL (Let's Encrypt):**
```bash
sudo certbot --nginx -d api.thestudioinfinito.com
```

### Option B: Hostinger Shared Hosting (Node.js)
If your Hostinger plan supports Node.js:
1. **hPanel** → Websites → Node.js
2. Set **Root directory**: `backend`
3. Set **Startup file**: `src/server.js`
4. Set **Node version**: 18.x
5. Add environment variables in hPanel
6. Connect GitHub repo for auto-deploy

---

## 3. Hostinger Frontend Deployment

### Build Flutter Web:
```bash
cd frontend
flutter build web --release
```

### Upload to Hostinger:
1. **hPanel** → File Manager → `public_html/`
2. Upload all files from `frontend/build/web/`

### Or use Git Deploy:
1. **hPanel** → Advanced → Git
2. Connect GitHub repo (branch: `main`)
3. Set auto-deploy path to `public_html/`

### Configure `.htaccess` for SPA routing:
Create `public_html/.htaccess`:
```apache
RewriteEngine On
RewriteBase /
RewriteRule ^index\.html$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.html [L]
```

---

## 4. GitHub Repository

**URL**: https://github.com/sam7399/Studioinfinito

### Auto-Deploy on Push:
Set up a GitHub Action for automated deployment:

```yaml
# .github/workflows/deploy.yml
name: Deploy
on:
  push:
    branches: [main]
jobs:
  deploy-backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to VPS
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.VPS_HOST }}
          username: ${{ secrets.VPS_USER }}
          key: ${{ secrets.VPS_SSH_KEY }}
          script: |
            cd ~/Studioinfinito/backend
            git pull origin main
            npm install --production
            pm2 restart tsi-backend
```

---

## Environment Variables Reference

### Required:
| Variable | Description | Example |
|----------|-------------|---------|
| `NODE_ENV` | Environment | `production` |
| `PORT` | Server port | `26627` |
| `JWT_SECRET` | JWT signing key | `min-32-char-secret-here` |
| `DBHOST` | Supabase DB host | `db.xxxx.supabase.co` |
| `DBPORT` | Database port | `5432` |
| `DBNAME` | Database name | `postgres` |
| `DBUSER` | Database user | `postgres` |
| `DBPASS` | Database password | `your-supabase-password` |
| `DBSSL` | Enable SSL | `true` |

### Optional (Email):
| Variable | Description | Example |
|----------|-------------|---------|
| `EMAILHOST` | SMTP host | `smtp.gmail.com` |
| `EMAILPORT` | SMTP port | `587` |
| `EMAILUSER` | SMTP username | `your@gmail.com` |
| `EMAILPASS` | SMTP app password | `xxxx xxxx xxxx xxxx` |
| `EMAIL_FROM` | From address | `TSI <noreply@domain.com>` |

### URLs:
| Variable | Description | Example |
|----------|-------------|---------|
| `BASE_URL_API` | Backend API URL | `https://api.thestudioinfinito.com` |
| `BASE_URL_APP` | Frontend app URL | `https://task.thestudioinfinito.com` |
| `CORS_ORIGINS` | Allowed origins | `https://task.thestudioinfinito.com` |

---

## Health Check

Verify deployment: `GET /api/v1/health`

```json
{
  "status": "ok",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "version": "1.0.0"
}
```

---

## Troubleshooting

### Supabase DB:
- **Connection refused**: Check `DBSSL=true` is set
- **Auth failed**: Verify password in Supabase Settings → Database
- **Test connection**: `psql "postgresql://postgres:<password>@db.<ref>.supabase.co:5432/postgres"`

### Hostinger Backend:
- Check PM2 logs: `pm2 logs tsi-backend`
- Check Nginx logs: `sudo tail -f /var/log/nginx/error.log`
- Verify Node.js version: `node -v` (should be 18.x+)

### Hostinger Frontend:
- Clear browser cache after deploy
- Check `.htaccess` exists for SPA routing
- Verify `frontend/.env` API URL points to correct backend

---

## Quick Deploy Checklist

- [ ] Supabase project created and connection details copied
- [ ] Push latest code to GitHub
- [ ] Backend `.env` configured with Supabase credentials
- [ ] Backend deployed on Hostinger (VPS or Node.js hosting)
- [ ] PM2 running + Nginx configured with SSL
- [ ] Migrations ran successfully (`npm run db:migrate`)
- [ ] Health check responding at `/api/v1/health`
- [ ] Frontend built (`flutter build web --release`)
- [ ] Frontend uploaded to Hostinger `public_html/`
- [ ] `.htaccess` configured for SPA routing
- [ ] CORS origins set correctly in backend `.env`
- [ ] Test login with seeded admin account

---

**Live URLs:**
- Frontend: https://task.thestudioinfinito.com
- Backend API: https://api.thestudioinfinito.com/api/v1
- Health Check: https://api.thestudioinfinito.com/api/v1/health
- Supabase Dashboard: https://supabase.com/dashboard
