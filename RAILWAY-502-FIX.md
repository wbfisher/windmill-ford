# Fixing Railway 502 Error - Step by Step

## The Problem
Your Railway deployment is returning a 502 Bad Gateway error because **Windmill cannot start without a PostgreSQL database connection**.

## Root Cause
The Windmill service is trying to start, but one of these issues is occurring:

1. ❌ No PostgreSQL database service exists in your Railway project
2. ❌ The `DATABASE_URL` environment variable is not set
3. ❌ The database service name doesn't match the variable reference
4. ❌ The database service hasn't finished initializing

## Step-by-Step Fix

### Step 1: Check if PostgreSQL Database Exists

1. Go to your Railway Dashboard
2. Open your project (windmill-ford-production)
3. Look at the services list

**Do you see a PostgreSQL database service?**
- If **NO** → Go to Step 2 (Create Database)
- If **YES** → Go to Step 3 (Check Environment Variables)

---

### Step 2: Create PostgreSQL Database (If Missing)

1. In your Railway project, click **"New"**
2. Select **"Database"**
3. Choose **"PostgreSQL"**
4. Name it: `windmill-db`
5. Click **"Add"**
6. **Wait 30-60 seconds** for it to show "Active" status

---

### Step 3: Configure Environment Variables

1. Click on your **Windmill service** (not the database)
2. Go to the **"Variables"** tab
3. Check if these variables exist:

**Required Variables:**

| Variable Name | Value |
|--------------|-------|
| `DATABASE_URL` | `${{windmill-db.DATABASE_URL}}` |
| `MODE` | `standalone` |
| `WM_BASE_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` |

**If any are missing, add them:**

#### How to Add Variables:
1. Click **"New Variable"**
2. Enter the exact name (e.g., `DATABASE_URL`)
3. Enter the exact value (e.g., `${{windmill-db.DATABASE_URL}}`)
4. Click **"Add"**
5. Repeat for each missing variable

**IMPORTANT:**
- The syntax `${{windmill-db.DATABASE_URL}}` must match your database service name exactly
- If you named your database something else (e.g., `postgres`), use `${{postgres.DATABASE_URL}}`

---

### Step 4: Verify Database Service Name Matches

1. Look at your database service name (e.g., `windmill-db`)
2. Look at your `DATABASE_URL` value: `${{windmill-db.DATABASE_URL}}`
3. **The service name must match exactly** (case-sensitive)

**If they don't match:**
- Either rename the database service to `windmill-db`
- Or update the variable to match: `${{your-actual-db-name.DATABASE_URL}}`

---

### Step 5: Redeploy

1. Go to the **"Deployments"** tab of your Windmill service
2. Click **"Redeploy"**
3. Click **"View Logs"** to watch the startup

---

### Step 6: Check the Logs

Watch for these messages in the deployment logs:

#### ✅ GOOD - Service Starting Correctly:
```
=========================================
Windmill Railway Startup
=========================================
✓ DATABASE_URL is configured
✓ Starting Windmill on port 8000
✓ Mode: standalone
✓ Base URL: https://windmill-ford-production.up.railway.app
```

#### ❌ BAD - Missing Database URL:
```
❌ ERROR: DATABASE_URL environment variable is not set!

To fix this in Railway:
1. Create a PostgreSQL service: New → Database → PostgreSQL
2. Name it 'windmill-db'
3. Go to your Windmill service → Variables tab
...
```
**Fix:** Go back to Step 2 and create the database + set variables

#### ❌ BAD - Database Connection Failed:
```
Error: Connection refused
Could not connect to database
```
**Fix:**
- Make sure the database service shows "Active" status
- Wait 60 seconds and redeploy again
- Check that both services are in the same Railway project

---

## Verification

Once deployed successfully:

1. **Wait 60-90 seconds** for Windmill to fully initialize
2. Open your Railway URL: https://windmill-ford-production.up.railway.app
3. You should see the Windmill login page (NOT a 502 error)

**Default login:**
- Email: `admin@windmill.dev`
- Password: `changeme`

---

## Quick Checklist

Use this checklist to verify your setup:

- [ ] PostgreSQL database service exists and shows "Active"
- [ ] Database is named `windmill-db` (or you've updated variable references)
- [ ] `DATABASE_URL=${{windmill-db.DATABASE_URL}}` is set
- [ ] `MODE=standalone` is set
- [ ] `WM_BASE_URL=https://${{RAILWAY_PUBLIC_DOMAIN}}` is set
- [ ] Latest deployment shows successful startup in logs
- [ ] Waited at least 90 seconds after deployment
- [ ] Railway URL shows Windmill login page

---

## Still Not Working?

### Check Railway Service Logs

1. Go to your Windmill service
2. Click **"Deployments"**
3. Click on the latest deployment
4. Click **"View Logs"**
5. Look for error messages

### Common Issues

**"Application failed to respond"**
- The service is starting but taking too long
- Wait a full 90 seconds and refresh
- Check that healthcheck is passing

**"windmill-db.DATABASE_URL is not defined"**
- The database service name doesn't match
- Check the exact name of your PostgreSQL service
- Update the variable to use the correct name

**"Connection refused" or "Connection timeout"**
- Database hasn't finished initializing
- Wait 60 seconds and redeploy
- Ensure both services are in the same project

**Still seeing 502 after all fixes**
- Check if Railway quota/credits are exhausted
- Verify the service is actually running (not crashed)
- Try removing and re-adding the environment variables

---

## Need Help?

If you're still stuck after following these steps:

1. Share your deployment logs
2. Confirm which variables are set in the Variables tab
3. Confirm the database service status (Active/Crashed/Building)
4. Share any error messages from the logs

---

## Technical Details

**Why does this happen?**

Windmill is a complex application that requires:
- PostgreSQL database for storing workflows, users, and state
- Proper environment configuration
- Time to initialize (run migrations, start services)

Without a database connection, Windmill cannot start, causing:
1. Container starts
2. Windmill tries to connect to database
3. Connection fails (no DATABASE_URL or can't reach database)
4. Windmill exits with error
5. Railway marks service as unhealthy
6. Railway returns 502 to all requests

**What changed in the new Dockerfile?**

The updated Dockerfile adds:
- Startup validation (checks DATABASE_URL before starting)
- Clear error messages in logs
- Healthcheck endpoint so Railway knows when service is ready
- Better startup logging
