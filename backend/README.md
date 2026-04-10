# Task Manager Backend API

Production-ready Node.js backend for Multi-Company Task Management System.

## 🚀 Quick Start

### Prerequisites
- Node.js 18+ and npm
- MySQL 8+
- Windows Server (for IIS deployment)

### Installation

```bash
# Install dependencies
npm install

# Configure environment
cp .env.example .env
# Edit .env with your database and SMTP credentials

# Create database
mysql -u root -p -e "CREATE DATABASE task_manager CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# Run migrations
npm run db:migrate

# Seed base data (companies, departments, locations)
npm run db:seed

# Create superadmin user
node scripts/seed_admin.js Admin@123

# Start development server
npm start

# Or start with PM2 for production
npm run start:prod
```

## 📁 Project Structure

```
apps/backend/
├── src/
│   ├── config/           # Configuration files
│   ├── models/           # Sequelize models
│   ├── migrations/       # Database migrations
│   ├── middleware/       # Express middleware
│   ├── services/         # Business logic
│   ├── routes/           # API routes
│   ├── controllers/      # Request handlers
│   ├── mail/             # Email service & templates
│   ├── cron/             # Scheduled jobs
│   ├── utils/            # Utilities
│   ├── app.js            # Express app
│   └── server.js         # Server entry point
├── scripts/              # Utility scripts
├── pm2/                  # PM2 configuration
├── iis/                  # IIS web.config
├── tests/                # Test files
├── logs/                 # Application logs
├── uploads/              # Temporary file uploads
├── package.json
├── .env.example
└── README.md
```

## 🔧 Configuration

### Environment Variables

Edit `.env` file with your configuration:

```env
# Database
DBHOST=localhost
DBNAME=task_manager
DBUSER=root
DBPASS=your_password
DBPORT=3306

# JWT
JWT_SECRET=your-super-secret-jwt-key-min-32-characters-long
JWT_EXPIRES_IN=12h

# Email (SMTP)
EMAILHOST=smtp.gmail.com
EMAILPORT=587
EMAILSECURE=false
EMAILUSER=your-email@gmail.com
EMAILPASS=your-app-specific-password
EMAIL_FROM=Task Manager <no-reply@gemaromatics.com>

# URLs
BASE_URL_API=https://api.gemaromatics.com
BASE_URL_APP=https://app.gemaromatics.com

# CORS (comma-separated)
CORS_ORIGINS=https://app.gemaromatics.com,https://YOUR_PROJECT.web.app,https://YOUR_PROJECT.firebaseapp.com

# Server
PORT=26627
NODE_ENV=production
LOG_LEVEL=info
```

## 🗄️ Database

### Migrations

```bash
# Run all pending migrations
npm run db:migrate

# Rollback last migration
npm run db:migrate:undo
```

### Seeding

```bash
# Seed base data (companies, departments, locations)
npm run db:seed

# Create superadmin user
npm run seed:admin
# Or with custom password:
node scripts/seed_admin.js YourPassword123
```

## 🔐 Authentication

The API uses JWT (JSON Web Tokens) for authentication.

### Login
```http
POST /api/v1/auth/login
Content-Type: application/json

{
  "email": "admin@company.com",
  "password": "Admin@123"
}
```

Response:
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": { ... },
    "force_password_change": true
  }
}
```

### Using the Token

Include the token in the Authorization header:
```http
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

## 📡 API Endpoints

### Health Check
```http
GET /api/v1/health
```

### Authentication
- `POST /api/v1/auth/login` - User login
- `POST /api/v1/auth/forgot-password` - Request password reset
- `POST /api/v1/auth/reset-password` - Reset password with token
- `POST /api/v1/auth/change-password` - Change password (authenticated)

### Tasks
- `GET /api/v1/tasks` - List tasks (with filters & pagination)
- `GET /api/v1/tasks/:id` - Get task details
- `POST /api/v1/tasks` - Create task
- `PUT /api/v1/tasks/:id` - Update task
- `DELETE /api/v1/tasks/:id` - Delete task (superadmin/management only)
- `POST /api/v1/tasks/:id/complete` - Mark task as complete
- `POST /api/v1/tasks/:id/review` - Review completed task

### Users
- `GET /api/v1/users/:id/workload` - Get user workload statistics
- `GET /api/v1/users/:id/performance` - Get user performance metrics

### Import/Export
- `POST /api/v1/import/users/import` - Import users (CSV/XLSX)
- `GET /api/v1/import/users/export` - Export users
- `POST /api/v1/import/tasks/import` - Import tasks (CSV/XLSX)
- `GET /api/v1/import/tasks/export` - Export tasks

## 🎭 Role-Based Access Control (RBAC)

### Roles
1. **superadmin** - Full system access across all companies
2. **management** - Company-wide access
3. **department_head** - Department-level access
4. **manager** - Team-level access (their direct reports)
5. **employee** - Self-only access

### Privacy Masking

Out-of-scope tasks show:
- ✅ ID, status, priority, due date, progress, timestamps
- ✅ Department and location names
- ❌ Title (shows "[Restricted]")
- ❌ Description (null)
- ❌ User details

## 📧 Email Notifications

Automated emails are sent for:
- Task assignment
- Task completion (review required)
- Task review (approved/reopened)
- Password reset
- Review reminders (24h after completion)

Email templates are in `src/mail/templates/`.

## ⏰ Cron Jobs

### Review Reminders
- **Schedule**: Hourly
- **Purpose**: Send reminders for tasks pending review >24 hours
- **Throttling**: Max one reminder per 24 hours per task

## 🚀 Deployment (Windows Server + IIS)

### Step 1: Install Prerequisites

```powershell
# Install Node.js 18+
# Download from: https://nodejs.org/

# Install PM2 globally
npm install -g pm2

# Install MySQL 8+
# Download from: https://dev.mysql.com/downloads/mysql/
```

### Step 2: Install IIS Modules

1. Open IIS Manager
2. Install **Application Request Routing (ARR)**:
   - Download from: https://www.iis.net/downloads/microsoft/application-request-routing
3. Install **URL Rewrite**:
   - Download from: https://www.iis.net/downloads/microsoft/url-rewrite

### Step 3: Configure Backend

```powershell
# Clone/copy project to server
cd C:\inetpub\task-manager-backend

# Install dependencies
npm install --production

# Configure environment
copy .env.example .env
# Edit .env with production values

# Run migrations
npm run db:migrate

# Seed data
npm run db:seed
node scripts/seed_admin.js SecurePassword123

# Start with PM2
npm run start:prod

# Verify PM2 is running
pm2 list
pm2 logs tm-backend
```

### Step 4: Configure IIS Reverse Proxy

1. Create new website in IIS:
   - **Name**: api.gemaromatics.com
   - **Physical path**: C:\inetpub\task-manager-backend
   - **Binding**: HTTPS, Port 443
   - **SSL Certificate**: Install valid certificate

2. Copy `iis/web.config` to site root

3. Configure ARR:
   - Open IIS Manager → Server level
   - Double-click "Application Request Routing Cache"
   - Click "Server Proxy Settings" (right panel)
   - Check "Enable proxy"
   - Apply changes

4. Test configuration:
   ```powershell
   # Test local backend
   curl http://localhost:26627/api/v1/health

   # Test through IIS
   curl https://api.gemaromatics.com/api/v1/health
   ```

### Step 5: Firewall Configuration

```powershell
# Allow HTTPS (443) - external access
New-NetFirewallRule -DisplayName "HTTPS" -Direction Inbound -LocalPort 443 -Protocol TCP -Action Allow

# Block backend port (26627) - internal only
New-NetFirewallRule -DisplayName "Block Backend" -Direction Inbound -LocalPort 26627 -Protocol TCP -Action Block
```

### Step 6: PM2 Startup

```powershell
# Save PM2 process list
pm2 save

# Generate startup script
pm2 startup

# Follow the instructions provided by PM2
```

## 🧪 Testing

```bash
# Run all tests
npm test

# Run tests in watch mode
npm run test:watch

# Run with coverage
npm test -- --coverage
```

## 📊 Logging

Logs are stored in `logs/` directory:
- `combined-YYYY-MM-DD.log` - All logs
- `error-YYYY-MM-DD.log` - Error logs only
- `exceptions-YYYY-MM-DD.log` - Uncaught exceptions
- `rejections-YYYY-MM-DD.log` - Unhandled promise rejections

Logs rotate daily and are kept for 14 days.

## 🔍 Troubleshooting

### Database Connection Issues
```bash
# Test MySQL connection
mysql -h localhost -u root -p -e "SELECT 1;"

# Check if database exists
mysql -u root -p -e "SHOW DATABASES LIKE 'task_manager';"
```

### PM2 Issues
```bash
# Check PM2 status
pm2 list

# View logs
pm2 logs tm-backend

# Restart application
pm2 restart tm-backend

# Delete and restart
pm2 delete tm-backend
npm run start:prod
```

### IIS Issues
```bash
# Check if backend is running
curl http://localhost:26627/api/v1/health

# Check IIS logs
# Location: C:\inetpub\logs\LogFiles\

# Test URL Rewrite
# Enable Failed Request Tracing in IIS
```

### Email Issues
```bash
# Test SMTP connection
# Use a tool like telnet or online SMTP tester

# Check email logs
# Search for "Email" in logs/combined-*.log
```

## 📝 Scripts

- `npm start` - Start development server
- `npm run start:prod` - Start with PM2 (production)
- `npm run dev` - Start with nodemon (auto-reload)
- `npm run db:migrate` - Run database migrations
- `npm run db:migrate:undo` - Rollback last migration
- `npm run db:seed` - Seed base data
- `npm run seed:admin` - Create superadmin user
- `npm test` - Run tests
- `npm run lint` - Run ESLint
- `npm run format` - Format code with Prettier

## 🔒 Security Best Practices

1. **Environment Variables**: Never commit `.env` file
2. **JWT Secret**: Use strong random string (min 32 chars)
3. **Database**: Use strong passwords, restrict network access
4. **CORS**: Only allow trusted origins
5. **Rate Limiting**: Configured for API, auth, and import endpoints
6. **HTTPS**: Always use HTTPS in production
7. **Firewall**: Block direct access to backend port (26627)
8. **Updates**: Keep dependencies updated

## 📚 Additional Resources

- [Sequelize Documentation](https://sequelize.org/docs/v6/)
- [Express.js Guide](https://expressjs.com/en/guide/routing.html)
- [PM2 Documentation](https://pm2.keymetrics.io/docs/usage/quick-start/)
- [IIS URL Rewrite](https://docs.microsoft.com/en-us/iis/extensions/url-rewrite-module/)

## 🆘 Support

For issues or questions:
1. Check logs in `logs/` directory
2. Review this README
3. Check API documentation
4. Contact system administrator

---

**Built for Gem Aromatics** | Production-Ready | Windows Server Compatible