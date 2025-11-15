# Railway Setup - CRITICAL FIRST STEPS

## ⚠️ BEFORE DEPLOYING: Set Up Environment Variables

The error `DATABASE_URL env var is missing` means you need to configure Railway first.

## Step-by-Step Fix

### 1. Create PostgreSQL Database Services FIRST

**In Railway Dashboard:**

1. Click **"New"** → **"Database"** → **"PostgreSQL"**
2. Name it: `windmill-db`
3. **Wait for it to show "Active"** (30-60 seconds)

### 2. Add Environment Variables to Windmill Service

**Go to your Windmill service → "Variables" tab**

Click **"New Variable"** and add these **ONE BY ONE**:

```bash
# REQUIRED - Database connection (replace with your actual service name)
DATABASE_URL=${{windmill-db.DATABASE_URL}}

# REQUIRED - Windmill mode
MODE=standalone

# REQUIRED - Base URL (Railway will auto-fill this)
WM_BASE_URL=https://${{RAILWAY_PUBLIC_DOMAIN}}

# OPTIONAL - Disable secure cookies for testing
DISABLE_SECURE_COOKIES=true
```

### 3. How to Reference Database Service

The syntax `${{windmill-db.DATABASE_URL}}` tells Railway to:
- Find the service named `windmill-db`
- Get its `DATABASE_URL` variable
- Inject it into your Windmill service

**IMPORTANT:** The service name must match EXACTLY:
- If you named it `windmill-db` → use `${{windmill-db.DATABASE_URL}}`
- If you named it `postgres` → use `${{postgres.DATABASE_URL}}`
- If you named it `db` → use `${{db.DATABASE_URL}}`

### 4. Redeploy

After adding the variables:
1. Go to **"Deployments"** tab
2. Click **"Redeploy"**
3. Watch the logs - you should see Windmill starting up

---

## Full Variable List (Copy-Paste Ready)

### Minimum Required Variables:
```
DATABASE_URL=${{windmill-db.DATABASE_URL}}
MODE=standalone
WM_BASE_URL=https://${{RAILWAY_PUBLIC_DOMAIN}}
```

### With Fleet Database (for Ford Pro integration):
```
DATABASE_URL=${{windmill-db.DATABASE_URL}}
FLEET_DATABASE_URL=${{fleet-db.DATABASE_URL}}
MODE=standalone
WM_BASE_URL=https://${{RAILWAY_PUBLIC_DOMAIN}}
FORD_PRO_CLIENT_ID=your_client_id_here
FORD_PRO_CLIENT_SECRET=your_client_secret_here
FORD_PRO_FLEET_ID=your_fleet_id_here
```

---

## Visual Guide

```
Railway Project Structure:

1. Create PostgreSQL service first:
   [windmill-db] ← PostgreSQL service

2. Create GitHub service second:
   [windmill] ← Your app from GitHub
   └── Variables:
       ├── DATABASE_URL=${{windmill-db.DATABASE_URL}}
       ├── MODE=standalone
       └── WM_BASE_URL=https://${{RAILWAY_PUBLIC_DOMAIN}}
```

---

## Troubleshooting

### "Application failed to respond"
**This means a port configuration issue.**

**Root Cause:** Railway can't connect to the application on the expected port.

**Solution:**
1. **Check the deployment logs** for errors:
   - Click Deployments → Latest → View Logs
   - Look for "Server listening on port 8000" or similar
   - Check for database connection errors

2. **Verify DATABASE_URL is set:**
   - The app won't start without it
   - Go to Variables tab and confirm `DATABASE_URL=${{windmill-db.DATABASE_URL}}`

3. **Wait for full startup:**
   - Windmill can take 60-90 seconds to fully start
   - Railway might timeout before Windmill is ready
   - Look for "Windmill started" or similar in logs

4. **Check the database is ready:**
   - Make sure `windmill-db` service shows "Active"
   - Redeploy the Windmill service after database is confirmed running

**The fix in latest code:** The Dockerfile now properly exposes port 8000 for Railway.

### "windmill-db.DATABASE_URL is not defined"
**Fix:** Make sure the PostgreSQL service is named exactly `windmill-db` or update the reference to match your service name.

### "Could not connect to server"
**Fix:** Wait 60 seconds for the database to fully initialize, then redeploy.

### "Connection refused"
**Fix:** Both services must be in the same Railway project. Verify they're both visible in your project dashboard.

### "Bad config: DATABASE_URL env var is missing"
**Fix:** See Step 2 above - add the required environment variables before deploying.

---

## Quick Copy-Paste for Railway Variables Tab

**Variable 1:**
```
Name: DATABASE_URL
Value: ${{windmill-db.DATABASE_URL}}
```

**Variable 2:**
```
Name: MODE
Value: standalone
```

**Variable 3:**
```
Name: WM_BASE_URL
Value: https://${{RAILWAY_PUBLIC_DOMAIN}}
```

Click **"Add"** after each variable, then **"Redeploy"**.

---

## Success Indicator

When configured correctly, your logs should show:
```
✓ Connected to database
✓ Running migrations
✓ Server listening on port 8000
✓ Windmill is ready
```

Access your app at the Railway-provided URL (found in Settings → Domains).
