# SMSI Fleet Dashboard

## Overview
Fleet vehicle safety monitoring system for Springfield Mechanical Services, Inc.
- Pulls safety metrics from Ford Pro Telematics API
- Stores in PostgreSQL for historical tracking
- Provides department-level safety dashboards
- Built on Windmill for workflow orchestration

## Architecture
```
Ford Pro API → Windmill Scripts → PostgreSQL → Windmill Dashboard
                     ↑
            Scheduled/Manual Triggers
```

## 🚀 Quick Start (Railway Deployment)

**Getting the "DATABASE_URL env var is missing" error?** → See [RAILWAY-QUICK-START.md](RAILWAY-QUICK-START.md)

### Step 1: Create Database Service
1. In Railway Dashboard: **New** → **Database** → **PostgreSQL**
2. Name it: `windmill-db`
3. Wait for it to show "Active"

### Step 2: Configure Environment Variables
Go to your Windmill service → **Variables** tab → Add:

```bash
DATABASE_URL=${{windmill-db.DATABASE_URL}}
MODE=standalone
WM_BASE_URL=https://${{RAILWAY_PUBLIC_DOMAIN}}
```

See [.env.railway.example](.env.railway.example) for all available variables.

### Step 3: Deploy
Click **Redeploy** and watch the logs. When successful, access Windmill at your Railway URL.

📖 **Full deployment guide:** [RAILWAY-DEPLOYMENT.md](RAILWAY-DEPLOYMENT.md)

---

## Detailed Setup Instructions

### 1. Railway Deployment (Alternative Method)
```bash
# Install Railway CLI
npm install -g @railway/cli

# Login and create project
railway login
railway init

# Deploy Windmill stack
railway up
```

### 2. Environment Variables
See [.env.railway.example](.env.railway.example) for:
- Ford Pro API credentials
- Database connection strings
- Windmill configuration

### 3. Database Setup
Run the schema migration in `/database/schema.sql`

### 4. Import Windmill Workflows
1. Access Windmill at your Railway URL
2. Import scripts from `/windmill/scripts/`
3. Import flows from `/windmill/flows/`
4. Configure schedules

## Data Structure

### Safety Metrics Tracked
- Harsh braking events
- Rapid acceleration
- Speeding incidents
- Seatbelt usage
- Collision alerts

### Scoring System
- Daily driver scores (0-100)
- Department rollups
- Monthly trends
- Risk categorization

## Future Integrations
- [ ] ADP (Employee data)
- [ ] Absorb (Training completion)
- [ ] Entra ID SSO
- [ ] Email alerts for safety incidents
