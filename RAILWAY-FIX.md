# Railway Deployment - TOML Error Fix

## The Problem
Railway is finding a `railway.toml` file with invalid syntax in your GitHub repo. Railway doesn't need this file for docker-compose deployments.

## Quick Fix (in your GitHub repo)

```bash
# Remove the bad files
git rm railway.toml railway.json 2>/dev/null || true

# Add ignore file
echo "railway.toml" > .railwayignore

# Commit and push
git add .
git commit -m "Remove railway config files - use docker-compose"
git push origin main
```

## Alternative Deployment Methods

### Method 1: Direct Template Deploy (Bypass GitHub)
1. Go to Railway Dashboard
2. Click "New Project"
3. Choose "Empty Project"
4. Add services manually:
   - Click "New" → "Database" → "PostgreSQL" (name it `windmill-db`)
   - Click "New" → "Database" → "PostgreSQL" (name it `fleet-db`)
   - Click "New" → "Docker Image" → Enter: `ghcr.io/windmill-labs/windmill:latest`

5. Configure Windmill service variables:
   ```
   DATABASE_URL=${{windmill-db.DATABASE_URL}}
   FLEET_DATABASE_URL=${{fleet-db.DATABASE_URL}}
   MODE=standalone
   WM_BASE_URL=https://${{RAILWAY_PUBLIC_DOMAIN}}
   FORD_PRO_CLIENT_ID=your_client_id
   FORD_PRO_CLIENT_SECRET=your_secret
   FORD_PRO_FLEET_ID=your_fleet_id
   ```

### Method 2: Railway CLI (Most Reliable)
```bash
# Don't use GitHub, deploy directly
cd smsi-fleet-dashboard

# Login and create project
railway login
railway init

# Deploy services one by one
railway add
# Choose PostgreSQL, name it "windmill-db"

railway add  
# Choose PostgreSQL, name it "fleet-db"

railway add
# Choose Docker, use windmill image

# Link and deploy
railway up --service windmill
```

### Method 3: Fork Our Clean Template
1. Go to: https://github.com/railway-templates/windmill
2. Fork it
3. Add your fleet-specific files:
   - `database/schema.sql`
   - `windmill/scripts/`
   - `windmill/flows/`
4. Deploy the forked repo

## Verification Steps

After deployment, verify:

1. **Check Railway logs:**
   ```bash
   railway logs
   ```

2. **Test Windmill access:**
   - Open the Railway-provided URL
   - Should see Windmill login page

3. **Initialize databases:**
   ```bash
   railway run --service fleet-db psql < database/schema.sql
   ```

## Still Getting Errors?

The TOML error specifically means Railway found a file named `railway.toml` with this content:
```
services:
  windmill:
    image: ...
```

This is docker-compose syntax, not TOML. Railway is trying to parse it as TOML and failing on the `:` character.

**Solution:** Ensure NO railway.toml exists in your repo. Railway will automatically use docker-compose.yml instead.
