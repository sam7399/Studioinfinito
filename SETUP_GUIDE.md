# Studioinfinito Task Manager - Setup Guide

## Prerequisites

- **Node.js**: v18+ (backend)
- **PostgreSQL**: v15+ (or Supabase free tier)
- **Flutter**: v3.19+ (frontend)
- **Git**: Latest version

---

## Backend Setup

### 1. Install Dependencies

```bash
cd backend
npm install
```

### 2. Configure Environment

Edit `backend/.env` with your settings:

```env
# Supabase PostgreSQL (required)
DBHOST=db.<your-project-ref>.supabase.co
DBNAME=postgres
DBUSER=postgres
DBPASS=your-supabase-password
DBPORT=5432
DBSSL=true

# JWT Secret (required - min 32 chars)
JWT_SECRET=your-super-secret-jwt-key-min-32-characters-long

# Email (optional - skip for development)
EMAILHOST=smtp.gmail.com
EMAILUSER=your-email@gmail.com
EMAILPASS=your-app-password
```

### 3. Setup Database

```bash
# Option 1: Create Supabase project at https://supabase.com
# Copy connection details to .env

# Option 2: Run migrations (creates tables automatically)
npm run db:migrate

# Option 3: Full reset with seed data
npm run db:migrate:undo
npm run db:migrate
npm run seed:demo
```

### 4. Start Server

```bash
# Development
npm run dev

# Production
npm start
```

Server runs on: `http://localhost:26627`

---

## Frontend Setup

### 1. Install Dependencies

```bash
cd frontend
flutter pub get
```

### 2. Configure Environment

Edit `frontend/.env`:

```env
APP_NAME=TSI Task Manager
API_BASE_URL=http://localhost:26627/api/v1
WS_URL=ws://localhost:26627
```

### 3. Run Application

```bash
# Development (web)
flutter run -d chrome

# Build for production
flutter build web
```

---

## Available Scripts

### Backend

| Command | Description |
|---------|-------------|
| `npm run dev` | Start with hot-reload |
| `npm start` | Start production server |
| `npm run db:migrate` | Run database migrations |
| `npm run db:migrate:undo` | Undo last migration |
| `npm run seed:demo` | Seed database with demo data |
| `npm test` | Run tests |

---

## Default Accounts (After Seeding)

| Role | Email | Password |
|------|-------|----------|
| Super Admin | admin@example.com | Admin@123 |
| Manager | manager@example.com | Manager@123 |
| Employee | employee@example.com | Employee@123 |

---

## Project Structure

See `CODE_ARCHITECTURE.md` for detailed architecture documentation.

---

## Bug Fixes Applied

- ✅ Fixed mailer method name in `authService.js`
- ✅ Fixed column name `assigned_to` → `assigned_to_user_id` in `performanceService.js`
- ✅ Fixed nodemailer version `^8.0.1` → `^6.9.13`
- ✅ Relaxed email config validation for development
- ✅ Migrated from MySQL to PostgreSQL (Supabase)
- ✅ Converted all migrations and raw DDL to PostgreSQL syntax
- ✅ Replaced `mysql2` with `pg`/`pg-hstore` in dependencies

---

## GitHub Repository

**URL**: https://github.com/sam7399/Studioinfinito

```bash
git clone https://github.com/sam7399/Studioinfinito.git
cd Studioinfinito
```

---

## Support

For issues or questions, please open a GitHub issue.
