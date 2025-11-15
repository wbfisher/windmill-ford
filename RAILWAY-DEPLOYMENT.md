# Railway Deployment Guide - FIXED

## The Problem (SOLVED)
Railway was showing: `⚠ Script start.sh not found` because it couldn't detect how to build the app.

## The Solution
This repo now includes:
- ✅ `Dockerfile` - Railway will use this to build the Windmill service
- ✅ `railway.json` - Configures Railway to use Docker builder
- ✅ `start.sh` - Fallback script (though Dockerfile is preferred)
- ✅ `.railwayignore` - Excludes unnecessary files from deployment

## Deployment Steps

### Step 1: Create PostgreSQL Databases in Railway

You need TWO PostgreSQL databases:

1. **In Railway Dashboard:**
   - Click "New" → "Database" → "PostgreSQL"
   - Name it: `windmill-db`
   - Note the connection string

2. **Create second database:**
   - Click "New" → "Database" → "PostgreSQL"
   - Name it: `fleet-db`
   - Note the connection string

### Step 2: Deploy Windmill Service from GitHub

1. **In Railway Dashboard:**
   - Click "New" → "GitHub Repo"
   - Select this repository
   - Railway will automatically detect the Dockerfile

2. **Configure Environment Variables:**

   Click on the Windmill service → Variables tab → Add these:

   ```bash
   # Required - Link to your databases
   DATABASE_URL=${{windmill-db.DATABASE_URL}}
   FLEET_DATABASE_URL=${{fleet-db.DATABASE_URL}}

   # Windmill configuration
   MODE=standalone
   WM_BASE_URL=https://${{RAILWAY_PUBLIC_DOMAIN}}
   DISABLE_SECURE_COOKIES=false

   # Ford Pro API credentials (add your values)
   FORD_PRO_CLIENT_ID=your_client_id_here
   FORD_PRO_CLIENT_SECRET=your_client_secret_here
   FORD_PRO_FLEET_ID=your_fleet_id_here
   ```

3. **Generate a Public Domain:**
   - Go to Settings tab
   - Click "Generate Domain"
   - Railway will create a public URL like: `your-app.up.railway.app`

### Step 3: Initialize Fleet Database

1. **Connect to fleet-db:**
   - In Railway, click on `fleet-db` service
   - Click "Connect" tab
   - Copy the connection string

2. **Run the schema:**
   ```bash
   # If you have PostgreSQL client locally:
   psql "your-fleet-db-connection-string" < database/schema.sql

   # OR use Railway CLI:
   railway connect fleet-db
   # Then paste the contents of database/schema.sql
   ```

### Step 4: Access Windmill

1. Open your Railway-provided URL
2. You should see the Windmill login page
3. Default credentials (change these immediately):
   - Email: `admin@windmill.dev`
   - Password: `changeme`

### Step 5: Import Scripts and Flows

Follow the instructions in `DEPLOYMENT.md` to:
- Import Ford Pro sync scripts
- Import vehicle assignment scripts
- Set up the daily sync flow
- Configure the fleet dashboard

## Troubleshooting

### "start.sh not found" Error
**Solution:** Make sure `railway.json` is committed to your repo. Railway should use the Dockerfile.

### "Could not determine how to build"
**Solution:**
1. Check that `Dockerfile` exists in your repo
2. In Railway settings, verify Builder is set to "Dockerfile"
3. Try redeploying

### Database Connection Errors
**Solution:**
1. Verify both PostgreSQL services are running
2. Check that `DATABASE_URL` and `FLEET_DATABASE_URL` variables are set
3. Make sure the databases are referenced correctly: `${{windmill-db.DATABASE_URL}}`

### Port Issues
**Solution:** Railway automatically sets the `PORT` variable. The Dockerfile is configured to use port 8000, which Windmill expects.

### Application Won't Start
**Check the logs:**
```bash
# In Railway dashboard, click on Deployments → Latest → View Logs
```

Common issues:
- Missing environment variables
- Database not ready (wait 30 seconds and retry)
- Invalid Ford Pro credentials

## Architecture on Railway

```
Railway Project: windmill-ford
│
├── Service: windmill (Your App)
│   ├── Built from: Dockerfile
│   ├── Port: 8000
│   └── Public URL: https://your-app.up.railway.app
│
├── Service: windmill-db (PostgreSQL)
│   └── Used by: Windmill core (user accounts, scripts, etc.)
│
└── Service: fleet-db (PostgreSQL + TimescaleDB)
    └── Used by: Ford Pro data, fleet metrics, employee assignments
```

## Cost Estimate

- Windmill Service: ~$10-15/month
- PostgreSQL (windmill-db): ~$10/month
- PostgreSQL (fleet-db): ~$10/month
- **Total: ~$30-35/month**

Includes:
- 512MB RAM per service (scalable)
- Automatic backups
- SSL certificates
- Custom domain support

## Next Steps

1. ✅ Deploy to Railway (you're doing this now!)
2. Set up Ford Pro API sync (see `DEPLOYMENT.md`)
3. Import employee data
4. Configure vehicle assignments
5. Set up daily sync schedule
6. Add SSO/Entra ID authentication (optional)

## Support

- **Railway Docs:** https://docs.railway.app
- **Windmill Docs:** https://windmill.dev/docs
- **This Project:** See `DEPLOYMENT.md` for full setup guide

---

## Quick Commands

```bash
# View logs
railway logs

# Connect to database
railway connect fleet-db

# Restart service
railway restart

# Check status
railway status
```

Railway CLI: `npm install -g @railway/cli`
