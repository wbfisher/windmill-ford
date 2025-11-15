# SMSI Fleet Dashboard - Quick Reference

## 🚀 Quick Start

### Local Development
```bash
# Start everything locally
docker-compose up

# Access Windmill at http://localhost:8000
# Default login: admin@windmill.dev / changeme
```

### Deploy to Railway
```bash
railway login
railway init
railway up
```

## 📊 Key Features

### What This System Does
✅ Syncs Ford Pro telematics data daily  
✅ Calculates driver safety scores (0-100)  
✅ Tracks harsh braking, speeding, seatbelt usage  
✅ Department-level rollups and trends  
✅ Alerts for high-risk events  
✅ Vehicle-employee assignment tracking  

### Safety Scoring Logic
- **Overall Score**: Average of all behavior scores
- **High Risk**: Score < 70 (immediate attention needed)
- **Medium Risk**: Score 70-85 (monitoring required)
- **Low Risk**: Score > 85 (good performance)

### Event Severity Levels
- **Critical**: Collision or severe safety violation
- **High**: Multiple violations or dangerous behavior
- **Medium**: Occasional unsafe driving
- **Low**: Minor infractions

## 🔧 Common Operations

### Manual Data Sync
1. Go to Flows → daily_fleet_sync
2. Click "Run"
3. Set manual_trigger = true

### Assign Vehicle to Employee
1. Go to Scripts → vehicle_assignments
2. Run with:
   - action: 'assign'
   - employee_number: 'EMP001'
   - vehicle_vin: 'VEHICLE_VIN'
   - is_primary_driver: true/false

### Import Employees from CSV
1. Go to Scripts → import_employees
2. Paste CSV content
3. Run import

### View Department Performance
1. Open Apps → fleet_dashboard
2. Select date and department
3. Export data if needed

## 📈 Database Queries

### Find High-Risk Drivers
```sql
SELECT e.first_name, e.last_name, ds.overall_score
FROM daily_driver_scores ds
JOIN employees e ON ds.employee_id = e.id
WHERE ds.date = CURRENT_DATE - 1
  AND ds.overall_score < 70
ORDER BY ds.overall_score;
```

### Department Summary
```sql
SELECT d.name, 
       COUNT(DISTINCT e.id) as drivers,
       AVG(ds.overall_score) as avg_score
FROM departments d
JOIN employees e ON e.department_id = d.id
JOIN daily_driver_scores ds ON ds.employee_id = e.id
WHERE ds.date = CURRENT_DATE - 1
GROUP BY d.name;
```

### Recent Safety Events
```sql
SELECT * FROM safety_events
WHERE time >= NOW() - INTERVAL '24 hours'
  AND severity IN ('high', 'critical')
ORDER BY time DESC;
```

## 🔐 Adding SSO Later

When ready for Entra ID:
1. Windmill Settings → SSO → OIDC
2. Add Azure AD application
3. Configure redirect URLs
4. Map groups to Windmill roles

## 💰 Cost Breakdown

| Service | Monthly Cost |
|---------|-------------|
| Railway Hosting | $30-40 |
| Ford Pro API | Included with fleet |
| Total | **$30-40/month** |

Compare to:
- Retool: $300+/month
- Custom Development: $10,000+
- Airbyte + Reporting: $600+/month

## 🚨 Troubleshooting

### No Data Showing
```sql
-- Check last sync
SELECT * FROM sync_log 
ORDER BY started_at DESC LIMIT 5;

-- Check vehicle assignments
SELECT * FROM current_vehicle_assignments;
```

### Ford Pro Connection Failed
- Verify API credentials in Resources
- Check fleet_id is correct
- Ensure telematics is enabled in Ford Pro account

### High Memory Usage
- Reduce days_to_sync in daily flow
- Add pagination to large queries
- Enable TimescaleDB compression

## 📞 Getting Help

### Internal
- Brad: Overall system owner
- IT: Railway/infrastructure issues
- Fleet Manager: Vehicle assignments

### External
- Windmill Docs: https://windmill.dev/docs
- Railway Support: https://railway.app/help
- Ford Pro Support: Contact your representative

## 🎯 Future Roadmap

**Phase 2 (Next Month)**
- [ ] Email alerts for critical events
- [ ] Weekly performance reports
- [ ] Driver coaching recommendations

**Phase 3 (Q2 2025)**
- [ ] ADP integration (HR data)
- [ ] Absorb integration (training)
- [ ] Predictive risk scoring

**Phase 4 (Q3 2025)**
- [ ] Mobile app
- [ ] Entra ID SSO
- [ ] Advanced analytics

## 📝 Notes

- Data refreshes daily at 6 AM CST
- Historical data retained for 1 year
- Scores are relative to SMSI standards
- All times in Central Time Zone

---

**System Version**: 1.0.0  
**Last Updated**: November 2024  
**Owner**: SMSI Fleet Management
