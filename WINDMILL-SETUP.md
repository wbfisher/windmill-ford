# Windmill Setup Guide for Ford Pro Fleet Integration

This guide walks you through setting up Windmill on Railway to sync Ford Pro telematics data to your fleet database.

## Prerequisites

- Windmill running on Railway (see [RAILWAY-DEPLOYMENT.md](RAILWAY-DEPLOYMENT.md))
- Fleet database (PostgreSQL) on Railway
- Ford Pro API credentials (client_id, client_secret, fleet_id)

## Step 1: Initialize the Fleet Database

### Option A: Using Railway Dashboard (Recommended)

1. Go to Railway Dashboard → Select your `fleet-db` service
2. Click on the **Data** tab
3. Click **Query** to open the SQL console
4. Copy the contents of `/database/init-fleet-db.sql`
5. Paste into the query console and run

### Option B: Using psql CLI

```bash
# Get the DATABASE_URL from Railway
# Go to fleet-db service → Variables tab → Copy DATABASE_URL

# Run the initialization script
psql "YOUR_FLEET_DB_URL" < database/init-fleet-db.sql
```

**Verification:** You should see output confirming 8 tables were created:
- departments
- employees
- vehicles
- vehicle_assignments
- safety_events
- daily_driver_scores
- department_daily_scores
- sync_log

## Step 2: Access Your Windmill Instance

1. Go to Railway Dashboard → Select your Windmill service
2. Click on the **Deployments** tab → Find the latest successful deployment
3. Click on the public URL (e.g., `https://windmill-ford-production.up.railway.app`)
4. First-time login:
   - Username: `admin@windmill.dev`
   - Password: `changeme`
   - **Change this immediately after first login!**

## Step 3: Create Windmill Resources

Windmill uses "Resources" to store connection credentials. You need to create two resources:

### 3a. Create Ford Pro API Resource

1. In Windmill, go to **Resources** (left sidebar)
2. Click **+ Add Resource**
3. Choose **Custom** resource type
4. Configure:
   - **Name:** `ford_pro_api` (must match exactly)
   - **Resource type:** `ford_pro_api_config`
   - **Description:** Ford Pro Telematics API credentials

5. Click **Add field** for each of these:

| Field Name | Type | Value | Description |
|------------|------|-------|-------------|
| `client_id` | string | `your_ford_client_id` | Ford Pro OAuth Client ID |
| `client_secret` | string | `your_ford_secret` | Ford Pro OAuth Client Secret |
| `fleet_id` | string | `your_fleet_id` | Your Ford Pro Fleet ID |
| `api_base_url` | string | `https://api.fordpro.com` | Ford Pro API base URL (optional) |

6. Click **Save**

**Where to get Ford Pro credentials:**
- Log in to [Ford Pro Portal](https://www.fordpro.com/)
- Go to Settings → API Access → Developer Console
- Create a new application or view existing credentials
- Fleet ID is available under Fleet Management → Fleet Details

### 3b. Create Fleet Database Resource

1. In Windmill Resources page, click **+ Add Resource**
2. Choose **PostgreSQL** resource type
3. Configure:
   - **Name:** `fleet_db` (must match exactly)
   - **Resource type:** `postgresql`
   - **Description:** Fleet metrics database

4. Get your Railway fleet-db connection string:
   - Go to Railway → `fleet-db` service → **Variables** tab
   - Copy the `DATABASE_URL` value (starts with `postgresql://`)

5. In Windmill, choose connection method:

**Option A: Use Connection String (Easier)**
   - Paste the full DATABASE_URL

**Option B: Enter Fields Separately**
   - Extract values from your DATABASE_URL:
     ```
     postgresql://user:password@host:port/database
     ```
   - Fill in:
     - Host: (e.g., `postgres.railway.internal` or external hostname)
     - Port: `5432` (default)
     - Database: (usually `railway`)
     - Username: (from URL)
     - Password: (from URL)
     - SSL Mode: `require` (recommended for Railway)

6. Click **Test Connection** to verify
7. Click **Save**

## Step 4: Import Windmill Scripts

### 4a. Import Ford Pro Sync Script

1. In Windmill, go to **Scripts** (left sidebar)
2. Click **+ New Script**
3. Choose **TypeScript (Deno)**
4. Script details:
   - **Path:** `f/scripts/ford_pro_sync`
   - **Summary:** Sync Ford Pro telematics data
   - **Description:** Fetches safety events and driver behavior from Ford Pro API

5. Copy the entire contents of `/windmill/scripts/ford_pro_sync.ts`
6. Paste into the script editor
7. Click **Save**

### 4b. Test the Script

1. Click on the **Run** tab
2. The script expects these arguments:
   - `ford_pro_api`: Select `$res:ford_pro_api` from dropdown
   - `fleet_db`: Select `$res:fleet_db` from dropdown
   - `sync_type`: Choose `manual`
   - `days_to_sync`: Enter `7`

3. Click **Run Script**
4. Watch the logs for:
   - ✅ "Starting manual sync for last 7 days"
   - ✅ "Found X vehicles"
   - ✅ "Sync completed. Processed X events."

**Troubleshooting:**
- If you see authentication errors → Check Ford Pro API credentials
- If you see database errors → Verify fleet_db resource connection
- If no vehicles found → Verify your fleet_id is correct

## Step 5: Import Windmill Flow (Scheduled Sync)

### 5a. Import the Daily Sync Flow

1. In Windmill, go to **Flows** (left sidebar)
2. Click **+ New Flow**
3. Choose **Import from YAML**
4. Copy the contents of `/windmill/flows/daily_fleet_sync.yaml`
5. Paste into the import dialog
6. Click **Import**

### 5b. Configure the Schedule

The flow is configured to run daily at 6 AM (America/Chicago timezone).

To modify the schedule:
1. Open the flow in the editor
2. Go to **Settings** tab
3. Find **Schedule** section
4. Modify the cron expression:
   - Current: `0 6 * * *` (6 AM daily)
   - Examples:
     - `0 */4 * * *` (Every 4 hours)
     - `0 8 * * 1-5` (8 AM on weekdays only)
     - `*/15 * * * *` (Every 15 minutes for testing)

5. Click **Save**

### 5c. Test the Flow

1. Click **Run** → **Run flow now**
2. Watch the flow execution:
   - Module 1: Checks last sync time
   - Module 2: Runs Ford Pro sync
   - Module 3: Checks for high-risk events
   - Module 4: Calculates daily metrics
   - Module 5: Sends alerts

3. Verify results:
   - Go to **Runs** tab to see execution history
   - Check the fleet_db database for new data:
     ```sql
     -- Check sync log
     SELECT * FROM sync_log ORDER BY started_at DESC LIMIT 5;

     -- Check vehicles imported
     SELECT COUNT(*) FROM vehicles;

     -- Check safety events
     SELECT COUNT(*) FROM safety_events;
     ```

## Step 6: Verify Data Pipeline

### Check Database Tables

Connect to your fleet-db and run these queries:

```sql
-- 1. Check sync status
SELECT
    sync_type,
    status,
    started_at,
    completed_at,
    records_processed,
    error_message
FROM sync_log
ORDER BY started_at DESC
LIMIT 10;

-- 2. Check imported vehicles
SELECT
    vin,
    make,
    model,
    year,
    license_plate,
    created_at
FROM vehicles
ORDER BY created_at DESC;

-- 3. Check safety events
SELECT
    time,
    event_type,
    severity,
    speed_mph
FROM safety_events
ORDER BY time DESC
LIMIT 20;

-- 4. Check daily driver scores
SELECT
    date,
    employee_id,
    overall_score,
    harsh_brake_count,
    speeding_count
FROM daily_driver_scores
ORDER BY date DESC
LIMIT 20;

-- 5. Check department rollups
SELECT
    date,
    department_id,
    active_drivers,
    avg_overall_score,
    high_risk_drivers
FROM department_daily_scores
ORDER BY date DESC;
```

### Expected Results

After a successful sync, you should see:
- ✅ Sync log entry with status = 'completed'
- ✅ Vehicles matching your Ford Pro fleet
- ✅ Safety events from the past 7 days
- ✅ Daily driver scores calculated
- ✅ Department rollups generated

## Step 7: Set Up Other Scripts (Optional)

### Import Employee Data

1. Create script at `f/scripts/import_employees`
2. Copy `/windmill/scripts/import_employees.ts`
3. Use to bulk import employee data from CSV

### Manage Vehicle Assignments

1. Create script at `f/scripts/vehicle_assignments`
2. Copy `/windmill/scripts/vehicle_assignments.ts`
3. Use to assign/unassign vehicles to employees

## Troubleshooting

### Ford Pro API Connection Issues

**Error:** "Failed to get Ford Pro token"
- ✅ Verify client_id and client_secret in `ford_pro_api` resource
- ✅ Check if credentials are active in Ford Pro Portal
- ✅ Ensure your Ford Pro account has API access enabled

**Error:** "Failed to fetch vehicles"
- ✅ Verify fleet_id is correct
- ✅ Check if your account has access to the fleet
- ✅ Try the Ford Pro API directly to test credentials:
  ```bash
  curl -X POST https://api.fordpro.com/oauth/token \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=client_credentials&client_id=YOUR_ID&client_secret=YOUR_SECRET"
  ```

### Database Connection Issues

**Error:** "Connection refused" or "Unable to connect"
- ✅ Check fleet_db resource configuration
- ✅ Verify DATABASE_URL is correct in Railway
- ✅ Ensure fleet-db service is running in Railway
- ✅ Check if Railway private networking is enabled

**Error:** "relation does not exist"
- ✅ Run the init-fleet-db.sql script
- ✅ Verify you're connected to the right database
- ✅ Check if tables were created successfully

### Sync Running But No Data

**No vehicles found:**
- ✅ Verify fleet_id matches your Ford Pro fleet
- ✅ Check Ford Pro Portal to confirm vehicles exist
- ✅ Review API permissions for your credentials

**No safety events:**
- ✅ Check if vehicles have been active in the date range
- ✅ Verify events exist in Ford Pro Portal
- ✅ Try increasing `days_to_sync` parameter

**No employee assignments:**
- ✅ Import employee data first
- ✅ Create vehicle assignments using the assignment script
- ✅ Events without assignments will have null employee_id

## Next Steps

1. **Set up employee imports** - Populate the employees table
2. **Assign vehicles** - Link employees to vehicles
3. **Configure alerts** - Set up email/Slack notifications for critical events
4. **Build dashboard** - Import the fleet dashboard app
5. **Integrate with ADP** - Sync employee data automatically
6. **Integrate with Absorb** - Track training completion

## Resources

- [Windmill Documentation](https://docs.windmill.dev)
- [Ford Pro API Documentation](https://developer.fordpro.com/docs)
- [Railway Documentation](https://docs.railway.app)

## Support

If you encounter issues:
1. Check the sync_log table for error messages
2. Review Windmill script run logs
3. Verify all Railway services are running
4. Check Railway service logs for errors
