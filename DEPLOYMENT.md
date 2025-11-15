# SMSI Fleet Dashboard - Railway Deployment Guide

## Prerequisites
- Railway account (https://railway.app)
- Ford Pro API credentials
- GitHub account (optional but recommended)

## Step 1: Deploy to Railway

### Option A: Deploy via Railway Button (Easiest)
1. Push this code to your GitHub repository
2. Add a "Deploy on Railway" button to your repo
3. Click the button and Railway will auto-configure everything

### Option B: Manual Deployment
```bash
# Install Railway CLI
npm install -g @railway/cli

# Login to Railway
railway login

# Initialize new project
railway init

# Link to this directory
railway link

# Deploy the stack
railway up
```

## Step 2: Configure Environment Variables

In Railway Dashboard:
1. Go to your project
2. Click on each service (windmill, fleet-db, windmill-db)
3. Go to "Variables" tab
4. Add these variables:

### For Windmill Service:
```
FORD_PRO_CLIENT_ID=your_client_id
FORD_PRO_CLIENT_SECRET=your_secret
FORD_PRO_FLEET_ID=your_fleet_id
WM_BASE_URL=https://${{RAILWAY_PUBLIC_DOMAIN}}
```

### For Fleet Database:
```
POSTGRES_PASSWORD=generate_strong_password
```

## Step 3: Initialize Windmill

1. Open Windmill at your Railway URL
2. Login with default admin credentials (change immediately):
   - Email: admin@smsi.com
   - Password: changeme

3. Create Resources:
   - Go to Resources → Add Resource
   - Create "ford_pro_api" resource:
     ```json
     {
       "client_id": "$FORD_PRO_CLIENT_ID",
       "client_secret": "$FORD_PRO_CLIENT_SECRET",
       "fleet_id": "$FORD_PRO_FLEET_ID",
       "api_base_url": "https://api.fordpro.com"
     }
     ```
   
   - Create "fleet_db" PostgreSQL resource:
     - Use the Fleet Database connection string from Railway

## Step 4: Import Scripts and Flows

1. In Windmill, go to Scripts
2. Create new TypeScript script
3. Copy content from `/windmill/scripts/ford_pro_sync.ts`
4. Save as `ford_pro_sync`
5. Repeat for `vehicle_assignments.ts`

6. Go to Flows
7. Import the flow from `/windmill/flows/daily_fleet_sync.yaml`
8. Test the flow with manual trigger

## Step 5: Import Dashboard

1. Go to Apps in Windmill
2. Create new app
3. Import configuration from `/windmill/apps/fleet_dashboard.yaml`
4. Save and test the dashboard

## Step 6: Initial Data Setup

### Load Employee Data
Connect to fleet database and run:
```sql
-- Import your employees from CSV or manually add
INSERT INTO employees (employee_number, first_name, last_name, email, department_id)
VALUES 
  ('EMP001', 'John', 'Smith', 'jsmith@smsi.com', 1),
  ('EMP002', 'Jane', 'Doe', 'jdoe@smsi.com', 2);
  -- Add all employees
```

### Assign Vehicles
Use the Windmill UI or run the vehicle_assignments script:
1. Go to Scripts → vehicle_assignments
2. Run with:
   - action: 'assign'
   - employee_number: 'EMP001'
   - vehicle_vin: 'VIN_FROM_FORD_PRO'
   - is_primary_driver: true

## Step 7: Schedule Daily Sync

The flow is already configured to run daily at 6 AM CST.
To modify:
1. Go to Flows → daily_fleet_sync
2. Click on Schedule
3. Adjust the cron expression

## Step 8: Test Everything

1. **Manual Sync Test:**
   - Go to Flows → daily_fleet_sync
   - Click "Run" with manual_trigger = true
   - Check logs for any errors

2. **Dashboard Test:**
   - Go to Apps → fleet_dashboard
   - Verify data is displaying
   - Test date selector and filters

3. **Vehicle Assignment Test:**
   - Run vehicle_assignments script
   - Verify assignments appear in database

## Troubleshooting

### Ford Pro API Connection Issues
- Verify credentials in Resources
- Check API base URL (may vary by region)
- Ensure fleet_id is correct
- Check Ford Pro account has telematics access enabled

### Database Connection Issues
- Verify connection strings in Resources
- Check Railway service is running
- Ensure databases are initialized with schema

### No Data Showing
- Check sync_log table for errors
- Verify vehicle assignments are set up
- Ensure Ford Pro is returning data for your vehicles
- Check date ranges in queries

## Monitoring

### Daily Health Checks
1. Check sync_log table for successful runs
2. Monitor high_risk_drivers count
3. Review department_daily_scores trends

### Set Up Alerts
1. Configure SMTP in environment variables
2. Modify send_alerts script to send emails
3. Add Slack webhook for instant notifications

## Next Steps

1. **Add SSO (Entra ID):**
   - Will be configured in Windmill settings
   - Under Settings → SSO → OIDC

2. **Add More Data Sources:**
   - ADP: Create new sync script for employee data
   - Absorb: Pull training completion data
   - Integrate with existing Hangfire jobs

3. **Enhance Reporting:**
   - Add weekly/monthly roll-up views
   - Create driver scorecards
   - Build predictive risk models

4. **Mobile Access:**
   - Windmill dashboard is mobile-responsive
   - Consider building native app later

## Support

### Windmill Documentation
- https://windmill.dev/docs

### Railway Documentation  
- https://docs.railway.app

### Ford Pro API
- Contact your Ford Pro representative
- API docs provided with your account

### Database Queries
Check `/database/schema.sql` for table structures and relationships.

---

## Quick Commands Reference

```bash
# View logs
railway logs

# Access database
railway run psql $DATABASE_URL

# Restart services
railway restart

# Scale up workers (if needed)
railway scale windmill --replicas 2
```

## Cost Estimates

- Railway: ~$30-40/month
  - Windmill: $10-15
  - PostgreSQL (x2): $20-25
- Total: $30-40/month for self-hosted solution
- Compare to: Retool ($300+), Airbyte Cloud ($500+), custom development ($$$)
