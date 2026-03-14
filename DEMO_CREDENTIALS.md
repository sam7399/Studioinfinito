# Studio Infinito — Demo Credentials

> **App URL:** https://task.thestudioinfinito.com
> **API URL:** https://studioinfinito-api.onrender.com/api/v1

---

## How to Load Demo Data

Run this once on the backend server (local or Render shell):

```bash
cd backend
npm run seed:demo
```

Safe to re-run — existing records are skipped, nothing is duplicated.

---

## Demo Company & Structure

| Item | Value |
|------|-------|
| Company | Studio Infinito |
| Location | Head Office |
| Departments | Human Resources, Finance, Operations, Marketing |
| Total Users | 18 |

---

## Superadmin ⚠️ LOCKED

> The superadmin password **cannot be changed from the app**.
> To change it, update directly in the database:
> ```sql
> UPDATE users
> SET password_hash = '$2b$10$<new_bcrypt_hash>'
> WHERE emp_code = 'DEMO_SUPERADMIN';
> ```
> Or run: `node scripts/seed_admin.js <newpassword>` after deleting the existing record.

| Field | Value |
|-------|-------|
| Name | Demo Admin |
| Email | admin@demo.tsi |
| Username | demoadmin |
| Password | `TSI@Demo#2025` |
| Role | Superadmin |
| Emp Code | DEMO_SUPERADMIN |

**What superadmin can do:**
- See all companies, all users, all tasks (unrestricted)
- Create / edit / delete any user
- Create / edit / delete any task
- Access all reports and org settings
- Cannot have password changed from the frontend (locked)

---

## Management

| Field | Value |
|-------|-------|
| Name | Sarah Mitchell |
| Email | management@demo.tsi |
| Username | sarahmitchell |
| Password | `Demo@1234` |
| Role | Management |
| Emp Code | DEMO-MGT-001 |

**What management can do:**
- See all users and tasks within the company
- Create / edit tasks for anyone
- Delete tasks
- Approve / review tasks
- Access all reports

---

## Human Resources Department

### Dept Head
| Field | Value |
|-------|-------|
| Name | David Kumar |
| Email | hr.head@demo.tsi |
| Username | davidkumar |
| Password | `Demo@1234` |
| Role | Department Head |
| Emp Code | DEMO-HR-001 |

### Manager
| Field | Value |
|-------|-------|
| Name | Priya Sharma |
| Email | hr.mgr@demo.tsi |
| Username | priyasharma |
| Password | `Demo@1234` |
| Role | Manager |
| Emp Code | DEMO-HR-002 |
| Reports To | David Kumar (hr.head@demo.tsi) |

### Employees
| Name | Email | Username | Password | Emp Code | Reports To |
|------|-------|----------|----------|----------|------------|
| Rahul Singh | hr.emp1@demo.tsi | rahulsingh | `Demo@1234` | DEMO-HR-003 | Priya Sharma |
| Meera Patel | hr.emp2@demo.tsi | meerapatel | `Demo@1234` | DEMO-HR-004 | Priya Sharma |

---

## Finance Department

### Dept Head
| Field | Value |
|-------|-------|
| Name | James Wilson |
| Email | fin.head@demo.tsi |
| Username | jameswilson |
| Password | `Demo@1234` |
| Role | Department Head |
| Emp Code | DEMO-FIN-001 |

### Manager
| Field | Value |
|-------|-------|
| Name | Anita Gupta |
| Email | fin.mgr@demo.tsi |
| Username | anitagupta |
| Password | `Demo@1234` |
| Role | Manager |
| Emp Code | DEMO-FIN-002 |
| Reports To | James Wilson (fin.head@demo.tsi) |

### Employees
| Name | Email | Username | Password | Emp Code | Reports To |
|------|-------|----------|----------|----------|------------|
| Rohan Verma | fin.emp1@demo.tsi | rohanverma | `Demo@1234` | DEMO-FIN-003 | Anita Gupta |
| Sunita Joshi | fin.emp2@demo.tsi | sunitajoshi | `Demo@1234` | DEMO-FIN-004 | Anita Gupta |

---

## Operations Department

### Dept Head
| Field | Value |
|-------|-------|
| Name | Michael Chen |
| Email | ops.head@demo.tsi |
| Username | michaelchen |
| Password | `Demo@1234` |
| Role | Department Head |
| Emp Code | DEMO-OPS-001 |

### Manager
| Field | Value |
|-------|-------|
| Name | Kavita Reddy |
| Email | ops.mgr@demo.tsi |
| Username | kavitareddy |
| Password | `Demo@1234` |
| Role | Manager |
| Emp Code | DEMO-OPS-002 |
| Reports To | Michael Chen (ops.head@demo.tsi) |

### Employees
| Name | Email | Username | Password | Emp Code | Reports To |
|------|-------|----------|----------|----------|------------|
| Amit Nair | ops.emp1@demo.tsi | amitnair | `Demo@1234` | DEMO-OPS-003 | Kavita Reddy |
| Deepak Iyer | ops.emp2@demo.tsi | deepakiyer | `Demo@1234` | DEMO-OPS-004 | Kavita Reddy |

---

## Marketing Department

### Dept Head
| Field | Value |
|-------|-------|
| Name | Emma Thompson |
| Email | mkt.head@demo.tsi |
| Username | emmathompson |
| Password | `Demo@1234` |
| Role | Department Head |
| Emp Code | DEMO-MKT-001 |

### Manager
| Field | Value |
|-------|-------|
| Name | Nikhil Kapoor |
| Email | mkt.mgr@demo.tsi |
| Username | nikhilkapoor |
| Password | `Demo@1234` |
| Role | Manager |
| Emp Code | DEMO-MKT-002 |
| Reports To | Emma Thompson (mkt.head@demo.tsi) |

### Employees
| Name | Email | Username | Password | Emp Code | Reports To |
|------|-------|----------|----------|----------|------------|
| Pooja Mehta | mkt.emp1@demo.tsi | poojamehta | `Demo@1234` | DEMO-MKT-003 | Nikhil Kapoor |
| Arjun Das | mkt.emp2@demo.tsi | arjundas | `Demo@1234` | DEMO-MKT-004 | Nikhil Kapoor |

---

## Role Permissions Summary

| Role | See All Tasks | Edit Any Task | Delete Task | Dept Privacy Bypass | Change Password |
|------|:---:|:---:|:---:|:---:|:---:|
| Superadmin | ✅ Company + All | ✅ | ✅ | ✅ | ❌ Locked (app) |
| Management | ✅ Company | ✅ | ✅ | ✅ | ✅ |
| Dept Head | ✅ Own Dept | ✅ Own Dept | ❌ | ✅ Own Dept | ✅ |
| Manager | ✅ Team Tasks | ✅ Team | ❌ | ✅ Team | ✅ |
| Employee | ✅ All (masked) | ✅ Own | ❌ | ❌ | ✅ |

### Cross-Department Visibility Rule
- **Same department** → full task details visible
- **Other department** → sees **title** + **target date** only (description hidden)
- **Management / Dept Head / Manager / Superadmin** → always see full details

---

## Testing Cross-Department Task Visibility

1. Log in as **hr.emp1@demo.tsi** (HR Employee)
2. Create a task → assign to **fin.emp1@demo.tsi** (Finance Employee)
3. Log out → log in as **ops.emp1@demo.tsi** (Operations Employee)
4. Go to Tasks — the HR→Finance task appears with a 🔒 lock icon
5. Click it → you see only the **title** and **target date**
6. Description, assignee, progress are all hidden ✅

---

## Changing the Superadmin Password (Backend Only)

**Option A — Direct SQL (Render DB Console or local MySQL):**
1. Generate a bcrypt hash for your new password:
   ```bash
   node -e "const b=require('bcrypt'); b.hash('YourNewPass',10).then(console.log)"
   ```
2. Run in MySQL:
   ```sql
   UPDATE users
   SET password_hash = '<paste_hash_here>'
   WHERE emp_code = 'DEMO_SUPERADMIN';
   ```

**Option B — Node script:**
```bash
cd backend
node -e "
const {User}=require('./src/models');
User.update({password_hash:'YourNewPass'},{where:{emp_code:'DEMO_SUPERADMIN'}})
  .then(()=>{ console.log('Done'); process.exit(0); });
"
```
*(The model hook will bcrypt the plain password automatically.)*

---

*Last updated: 2026-03-14*
