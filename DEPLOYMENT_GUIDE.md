# Studioinfinito - Multi-Platform Deployment Guide

Your app is configured for deployment on **Railway**, **Render**, and **Hostinger**. Here's how to manage each:

---

## 1. Railway Deployment

### Current Config: `railway.json`
```json
{
  "build": { "builder": "NIXPACKS" },
  "deploy": {
    "startCommand": "cd backend && npm start",
    "healthcheckPath": "/api/v1/health"
  }
}
```

### Deploy Steps:
1. **Dashboard**: https://railway.app
2. **New Project** → Deploy from GitHub repo
3. **Add Variables** in Railway dashboard:
   ```
   NODE_ENV=production
   JWT_SECRET=<generate-strong-secret>
   DBHOST=<your-mysql-host>
   DBUSER=<db-user>
   DBPASS=<db-password>
   DBNAME=task_manager
   EMAILHOST=smtp.gmail.com
   EMAILUSER=<your-email>
   EMAILPASS=<app-password>
   ```
4. **Add MySQL**: New → Database → MySQL
5. **Domain**: Settings → Generate Domain (e.g., `yourapp.up.railway.app`)

### Update Frontend API URL:
```env
# frontend/.env
API_BASE_URL=https://yourapp.up.railway.app/api/v1
WS_URL=wss://yourapp.up.railway.app
```

---

## 2. Render Deployment

### Current Config: `render.yaml`
```yaml
version: "1"
projects:
- name: TSI Task Manager
  services:
  - type: web
    runtime: node
    buildCommand: npm install
    startCommand: node src/server.js
    rootDir: backend
```

### Deploy Steps:
1. **Dashboard**: https://dashboard.render.com
2. **Blueprint** → New Web Service from GitHub
3. **Use Blueprint**: Select `render.yaml` from repo
4. **Environment Variables** (set manually in dashboard):
   - All variables with `sync: false` in render.yaml need values
   - `JWT_SECRET`, `DBHOST`, `DBUSER`, `DBPASS`, etc.
5. **Database**: New → PostgreSQL (or connect external MySQL)
6. **Custom Domain**: Settings → Custom Domain → Add `api.thestudioinfinito.com`

### Production URLs:
- **API**: `https://task-manager-api.onrender.com` (or your custom domain)
- **Web App**: `https://task.thestudioinfinito.com` (Hostinger)

---

## 3. Hostinger Frontend Deployment

Since Hostinger is for **frontend only** (Flutter web build):

### Build & Deploy:
```bash
# 1. Build Flutter for web
cd frontend
flutter build web --release

# 2. Output is in: build/web/

# 3. Upload to Hostinger:
#    - File Manager → public_html/
#    - Upload all files from build/web/
```

### Or use Git + Hostinger hPanel:
1. **hPanel** → Advanced → Git
2. Connect GitHub repo
3. Set deployment path to `public_html/`
4. **Auto-deploy**: Enable on push to main

### Configure CORS:
Update `backend/.env` with your Hostinger domain:
```env
CORS_ORIGINS=https://task.thestudioinfinito.com,https://www.thestudioinfinito.com
BASE_URL_APP=https://task.thestudioinfinito.com
```

---

## Environment Variables Reference

### Required for All Platforms:
| Variable | Description | Example |
|----------|-------------|---------|
| `NODE_ENV` | Environment | `production` |
| `PORT` | Server port | `26627` (Railway/Render auto-set) |
| `JWT_SECRET` | JWT signing key | `min-32-char-secret-here` |
| `DBHOST` | Database host | `mysql.railway.internal` |
| `DBPORT` | Database port | `3306` |
| `DBNAME` | Database name | `task_manager` |
| `DBUSER` | Database user | `root` |
| `DBPASS` | Database password | `secure-password` |

### Optional (Email Features):
| Variable | Description | Example |
|----------|-------------|---------|
| `EMAILHOST` | SMTP host | `smtp.gmail.com` |
| `EMAILPORT` | SMTP port | `587` |
| `EMAILUSER` | SMTP username | `your@gmail.com` |
| `EMAILPASS` | SMTP app password | `xxxx xxxx xxxx xxxx` |
| `EMAIL_FROM` | From address | `TSI <noreply@domain.com>` |

### URL Configuration:
| Variable | Description | Example |
|----------|-------------|---------|
| `BASE_URL_API` | Backend API URL | `https://api.thestudioinfinito.com` |
| `BASE_URL_APP` | Frontend app URL | `https://task.thestudioinfinito.com` |
| `CORS_ORIGINS` | Allowed origins | `https://task.thestudioinfinito.com` |

---

## Database Migrations on Deploy

### Option 1: Auto-migrate on startup (Recommended)
Add to `backend/src/server.js` before server start:
```javascript
const { sequelize } = require('./models');

// Sync models (creates tables if not exist)
await sequelize.sync({ alter: false });
```

### Option 2: Manual migration command
```bash
# After deploy, run in Render/Railway console:
npm run migrate
```

### Option 3: Use Sequelize CLI with migration files
```bash
# Generate migration
npx sequelize-cli migration:generate --name create-users

# Run migrations
npx sequelize-cli db:migrate
```

---

## Health Check Endpoint

Verify deployment: `GET /api/v1/health`

Should return:
```json
{
  "status": "ok",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "version": "1.0.0"
}
```

---

## Troubleshooting

### Railway:
- Check **Deploy Logs** in dashboard
- Verify **Environment Variables** are set
- Check **Metrics** for resource limits

### Render:
- View **Logs** tab
- Check **Events** for startup failures
- Verify **Start Command**: `node src/server.js`

### Hostinger:
- Check **Error Logs** in hPanel
- Verify **PHP version** (not applicable for Flutter - static files only)
- Clear **Browser Cache** after deploy

### Database Connection Issues:
```bash
# Test connection from local:
mysql -h <DBHOST> -u <DBUSER> -p

# Check if database exists:
SHOW DATABASES;
USE task_manager;
SHOW TABLES;
```

---

## Recommended Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Hostinger     │     │   Railway/      │     │   Railway/      │
│   (Frontend)    │────▶│   Render        │◄────│   MySQL/        │
│                 │     │   (Backend API) │     │   PostgreSQL    │
│ task.thestudio  │     │                 │     │                 │
│ infinito.com    │     │ api.thestudio   │     │ mysql.railway   │
│                 │     │ infinito.com    │     │ .internal       │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │
        │ Flutter Web
        │ (Static files)
        ▼
   CDN/Cloudflare (optional)
```

---

## Quick Deploy Checklist

- [ ] Push latest code to GitHub
- [ ] Verify all env vars set in Railway/Render dashboard
- [ ] Database created and accessible
- [ ] Run migrations (`npm run migrate`)
- [ ] Health check endpoint responding
- [ ] Frontend built (`flutter build web`)
- [ ] Frontend uploaded to Hostinger
- [ ] CORS origins updated in backend
- [ ] Test login with seeded admin account

---

**Live URLs** (update these):
- Frontend: https://task.thestudioinfinito.com
- Backend API: https://your-service.railway.app/api/v1
- Health Check: https://your-service.railway.app/api/v1/health
