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

## Setup Instructions

### 1. Railway Deployment
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
Copy `.env.example` to `.env` and fill in:
- Ford Pro API credentials
- Database connection strings
- Windmill admin password

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
