# Quick Start Guide - Studioinfinito Development

**For experienced developers wanting to get up and running quickly.**

---

## 5-Minute Setup

### 1. Prerequisites Check
```bash
# Verify you have the essentials
node --version        # v14+
npm --version         # v6+
mysql -V              # 5.7+
flutter --version     # Latest
```

### 2. Clone/Navigate to Project
```bash
cd /home/ubuntu/Studioinfinito
```

### 3. Backend Setup
```bash
# Install and configure
cd backend
npm install
cp .env.example .env

# Edit .env with your settings (see template below)
nano .env

# Initialize database
npm run migrate
npm run seed        # Optional - add test data

# Start server
npm run dev         # Runs on port 26627
```

### 4. Frontend Setup (New Terminal)
```bash
# From Studioinfinito root
cd frontend
flutter pub get

# Verify .env is correct
cat .env            # Should show API_BASE_URL=http://localhost:5000/api/v1

# Start app
flutter run         # Or: flutter run -d chrome (for web)
```

**That's it!** Both should be running now.

---

## Environment Configuration

### Minimal .env for Backend (backend/.env)

```env
# Quick development setup - copy this into .env
NODE_ENV=development
PORT=26627

# Database (adjust DBPASS to your MySQL password)
DBHOST=localhost
DBNAME=task_manager
DBUSER=root
DBPASS=your_mysql_password
DBPORT=3306

# Security (generate with: openssl rand -base64 32)
JWT_SECRET=your-32-character-random-secret-here
JWT_EXPIRES_IN=12h

# Email (optional - skip if not needed for testing)
EMAILHOST=smtp.gmail.com
EMAILPORT=587
EMAILSECURE=true
EMAILUSER=your-email@gmail.com
EMAILPASS=your-app-password

# URLs (localhost defaults - usually fine for dev)
BASE_URL_API=http://localhost:26627
BASE_URL_APP=http://localhost:3000

# CORS (includes localhost by default in dev mode)
CORS_ORIGINS=http://localhost:3000

# Logging
LOG_LEVEL=debug
```

### Frontend Configuration (frontend/.env)

```env
# Should already be correct
APP_NAME=TSI Task Manager
API_BASE_URL=http://localhost:5000/api/v1
BUILD_FLAVOR=dev
ENABLE_FIREBASE=false
RESET_PASSWORD_ROUTE=/reset-password
```

⚠️ **Important:** If backend is on different host/port, update `API_BASE_URL` accordingly.

---

## Database Setup

### Quick MySQL Setup

```bash
# Create database
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS task_manager;"

# Run backend migrations (auto-creates tables)
cd backend
npm run migrate

# (Optional) Seed test data
npm run seed

# Verify tables created
mysql -u root -p task_manager -e "SHOW TABLES;"
```

### Create Test Users (Manual)

```bash
mysql -u root -p task_manager << EOF
INSERT INTO users (email, password_hash, firstname, lastname, company_id) VALUES
  ('test1@test.com', '$2b$10$...', 'Test', 'User One', 1),
  ('test2@test.com', '$2b$10$...', 'Test', 'User Two', 1);
EOF
```

Or use the Flutter app's registration feature instead.

---

## Common Commands

### Backend Commands
```bash
cd backend

# Start development server (with auto-reload)
npm run dev

# Start production-like server
npm start

# Run verification script
node verify-fixes.js

# Run tests (if available)
npm test

# Database migrations
npm run migrate        # Run all migrations
npm run migrate:undo   # Rollback last migration

# Database seeding
npm run seed           # Add test data
```

### Frontend Commands
```bash
cd frontend

# Install/update dependencies
flutter pub get
flutter pub upgrade

# Run on specific device/emulator
flutter run -d android      # Android emulator
flutter run -d ios          # iOS simulator
flutter run -d chrome       # Web browser
flutter run -d web          # Web (same as -d chrome)

# Build (produces APK/IPA/Web bundle)
flutter build android       # Builds APK
flutter build ios           # Builds IPA
flutter build web           # Builds web version

# Clean and rebuild
flutter clean
flutter pub get
flutter run

# Debug info
flutter doctor -v           # Full device/dependency check

# Run with verbose logging
flutter run -v

# Run verification script (from root)
node verify-frontend-fixes.js
```

### Testing Endpoints with cURL

```bash
# Register user
curl -X POST http://localhost:26627/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "newuser@test.com",
    "password": "Password123!",
    "firstname": "Test",
    "lastname": "User"
  }'

# Login and get token
TOKEN=$(curl -s -X POST http://localhost:26627/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test1@test.com",
    "password": "password"
  }' | jq -r '.token')

# Use token for authenticated requests
curl -X GET http://localhost:26627/api/v1/tasks \
  -H "Authorization: Bearer $TOKEN"

# Create task
curl -X POST http://localhost:26627/api/v1/tasks \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Task",
    "description": "Testing task creation",
    "priority": "high",
    "dueDate": "2026-04-15"
  }'

# Mark task complete (NEW in Phase 1)
curl -X POST http://localhost:26627/api/v1/tasks/1/complete \
  -H "Authorization: Bearer $TOKEN"
```

---

## Port Reference

| Service | Port | URL | Purpose |
|---------|------|-----|---------|
| Backend API | 26627 | http://localhost:26627 | REST API server |
| Backend API (v1 routes) | 26627 | http://localhost:26627/api/v1 | Versioned API endpoints |
| Frontend (Web) | 3000+ | http://localhost:3000 | Flutter web (if running on web) |
| Frontend (Mobile) | N/A | Device/Emulator | Android/iOS app |
| MySQL | 3306 | localhost:3306 | Database (internal only) |

---

## Typical Development Workflow

### Terminal Setup (3 terminals recommended)

**Terminal 1: Backend**
```bash
cd /home/ubuntu/Studioinfinito/backend
npm run dev
# Leaves running, watch for errors
```

**Terminal 2: Frontend**
```bash
cd /home/ubuntu/Studioinfinito/frontend
flutter run
# Leaves running, watch for errors
```

**Terminal 3: Command/Testing**
```bash
# Use for running commands, tests, curl requests, etc.
cd /home/ubuntu/Studioinfinito
# Run verification scripts, database commands, etc.
```

### Development Cycle

```bash
# 1. Make code changes
# (Backend or Frontend code)

# 2. Save changes
# (Auto-reload should trigger in dev servers)

# 3. Verify in app
# (Check frontend for visual changes or functionality)

# 4. Test API if backend changed
# (Use cURL in Terminal 3)

# 5. Check logs if something breaks
# (Look at Terminal 1 or 2 for errors)

# 6. If major changes, restart servers
# (Ctrl+C, then run npm run dev / flutter run again)
```

---

## Troubleshooting Quick Links

### "Port already in use"
```bash
# Find process on port 26627
lsof -i :26627

# Kill it
kill -9 <PID>

# Or change port in .env
# PORT=26628
```

### "Cannot connect to MySQL"
```bash
# Check if MySQL is running
mysql -u root -p -e "SELECT 1;"

# If not running, start it
# macOS: brew services start mysql
# Linux: sudo systemctl start mysql
# Windows: Use Services or SQL command line
```

### "CORS error in browser console"
```bash
# Add frontend URL to backend CORS_ORIGINS
# In backend/.env:
CORS_ORIGINS=http://localhost:3000,http://localhost:3001
# Restart backend
```

### "API not responding from frontend"
```bash
# 1. Verify backend is running: curl http://localhost:26627/api/v1/health
# 2. Check API_BASE_URL in frontend/.env
# 3. Verify CORS is configured in backend/.env
# 4. Check browser console for exact error message
```

### "Flutter build/run fails"
```bash
# Clean and reinstall dependencies
flutter clean
flutter pub get
flutter run

# For specific platform issues
flutter doctor -v
# Follow suggestions for your platform
```

---

## Code Changes & Git

### After Making Changes

```bash
# Check status
git status

# See what changed
git diff

# Stage changes
git add .

# Commit
git commit -m "Brief description of changes"

# Push to remote
git push origin your-branch-name
```

### Pull Latest Changes

```bash
# From project root
git pull origin main

# Update backend dependencies if package.json changed
cd backend && npm install

# Update frontend dependencies if pubspec.yaml changed
cd frontend && flutter pub get
```

---

## Quick Verification

### Backend Quick Check
```bash
cd backend
node verify-fixes.js
# Should show: ✨ All 8/8 critical checks PASSED!
```

### Frontend Quick Check
```bash
node verify-frontend-fixes.js
# Should show: ✨ All 4/4 critical checks PASSED!
```

### Full System Check
```bash
# Run both in Terminal 3
./backend/verify-fixes.js
./verify-frontend-fixes.js

# Manually test a few endpoints
curl http://localhost:26627/api/v1/health
# Should respond with health status
```

---

## Next Steps After Setup

1. **Review Documentation:**
   - `PHASE1_TESTING_GUIDE.md` - Full testing procedures
   - `ISSUES_FIXED_SUMMARY.md` - What was fixed and why
   - `FRONTEND_FIXES_SUMMARY.md` - Frontend-specific fixes
   - `FIXES_SUMMARY.md` - Backend-specific fixes

2. **Run Tests:**
   ```bash
   # Follow PHASE1_TESTING_GUIDE.md
   # Test all 6 key workflows
   ```

3. **Start Development:**
   ```bash
   # Make changes to code
   # Changes auto-reload in dev mode
   # Test in app
   # Commit and push when done
   ```

4. **Report Issues:**
   - Check troubleshooting section
   - Review recent error messages
   - Check database integrity
   - Create GitHub issue if bug found

---

## Development Tips

### Enable Debug Logging
```bash
# In backend/.env
LOG_LEVEL=debug

# In frontend, enable verbose output
flutter run -v
```

### Test Specific Endpoints
```bash
# Save token to variable for easier testing
export TOKEN="your_jwt_token_here"

# Then use in curl
curl -X GET http://localhost:26627/api/v1/tasks \
  -H "Authorization: Bearer $TOKEN"
```

### Monitor Database Changes
```bash
# In Terminal 3, watch a table
watch -n 1 'mysql -u root -p task_manager -e "SELECT * FROM tasks;"'

# Or run query repeatedly
while true; do
  clear
  mysql -u root -p task_manager -e "SELECT id, title, status FROM tasks;"
  sleep 2
done
```

### View Backend Logs Realtime
```bash
# Terminal 1 output is already visible
# To save logs to file:
npm run dev > backend.log 2>&1 &
tail -f backend.log  # Watch in another terminal
```

---

## Quick Command Reference

| Task | Command |
|------|---------|
| Start backend | `cd backend && npm run dev` |
| Start frontend | `cd frontend && flutter run` |
| Install backend deps | `cd backend && npm install` |
| Install frontend deps | `cd frontend && flutter pub get` |
| Setup database | `cd backend && npm run migrate` |
| Verify backend fixes | `cd backend && node verify-fixes.js` |
| Verify frontend fixes | `node verify-frontend-fixes.js` |
| Test login endpoint | `curl -X POST http://localhost:26627/api/v1/auth/login ...` |
| Get database shell | `mysql -u root -p task_manager` |
| View backend logs | See Terminal 1 output |
| View frontend logs | See Terminal 2 output |
| Clean flutter cache | `flutter clean` |
| Update git | `git pull origin main` |

---

## Environment Variable Quick Reference

### Backend (.env)
- `NODE_ENV` - Set to `development` for local work
- `PORT` - Backend port (default: 26627)
- `DBHOST/DBNAME/DBUSER/DBPASS` - MySQL connection
- `JWT_SECRET` - Authentication key (generate with openssl)
- `BASE_URL_API/BASE_URL_APP` - Application URLs
- `CORS_ORIGINS` - Allowed frontend origins
- `EMAIL*` - SMTP configuration (optional)

### Frontend (.env)
- `API_BASE_URL` - Backend URL (must match your backend)
- `APP_NAME` - Application title
- Other variables are optional for Phase 1

---

**Last Updated:** April 6, 2026  
**Version:** 1.0  
**Status:** Ready for Use
