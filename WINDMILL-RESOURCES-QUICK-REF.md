# Windmill Resources Quick Reference

Quick copy-paste reference for setting up Windmill resources.

## Resource 1: Ford Pro API

**Resource Name:** `ford_pro_api`
**Resource Type:** Custom / `ford_pro_api_config`

### Fields to Add:

```json
{
  "client_id": "your_ford_pro_client_id_here",
  "client_secret": "your_ford_pro_client_secret_here",
  "fleet_id": "your_ford_fleet_id_here",
  "api_base_url": "https://api.fordpro.com"
}
```

### Where to Get Credentials:

1. Go to [Ford Pro Portal](https://www.fordpro.com/)
2. Navigate to: **Settings → API Access → Developer Console**
3. Create application or view existing credentials
4. Fleet ID: **Fleet Management → Fleet Details**

---

## Resource 2: Fleet Database (PostgreSQL)

**Resource Name:** `fleet_db`
**Resource Type:** PostgreSQL

### Get Database URL from Railway:

1. Railway Dashboard → `fleet-db` service
2. **Variables** tab
3. Copy `DATABASE_URL`

### Connection String Format:

```
postgresql://username:password@host:port/database?sslmode=require
```

### Example (Railway):

```
postgresql://postgres:abc123@containers-us-west.railway.app:5432/railway?sslmode=require
```

### Fields (if entering separately):

| Field | Example Value |
|-------|---------------|
| Host | `containers-us-west.railway.app` |
| Port | `5432` |
| Database | `railway` |
| Username | `postgres` |
| Password | `[from Railway]` |
| SSL Mode | `require` |

---

## Quick Test Commands

### Test Ford Pro Connection (using curl):

```bash
curl -X POST https://api.fordpro.com/oauth/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=YOUR_CLIENT_ID" \
  -d "client_secret=YOUR_CLIENT_SECRET" \
  -d "scope=vehicle.telematics vehicle.info"
```

Expected response:
```json
{
  "access_token": "eyJ...",
  "token_type": "Bearer",
  "expires_in": 3600
}
```

### Test Fleet DB Connection (using psql):

```bash
psql "YOUR_DATABASE_URL" -c "SELECT version();"
```

Expected output:
```
                                                   version
--------------------------------------------------------------------------------------------------------------
 PostgreSQL 14.x on x86_64-pc-linux-gnu, compiled by gcc ...
```

---

## Resource Usage in Scripts

### TypeScript Script Example:

```typescript
import { Resource, type Sql } from "https://deno.land/x/windmill@v1.188.1/mod.ts";

export async function main(
  // Windmill auto-injects these from Resources
  ford_pro_api: Resource<{
    client_id: string;
    client_secret: string;
    fleet_id: string;
    api_base_url?: string;
  }>,
  fleet_db: Resource<Sql>
) {
  // Access Ford Pro credentials
  const clientId = ford_pro_api.client_id;
  const fleetId = ford_pro_api.fleet_id;

  // Query fleet database
  const result = await fleet_db.query(
    "SELECT COUNT(*) FROM vehicles"
  );

  return result.rows;
}
```

### SQL Script Example:

```sql
-- fleet_db is auto-injected as the connection
SELECT
  v.vin,
  v.make,
  v.model,
  COUNT(se.id) as total_events
FROM vehicles v
LEFT JOIN safety_events se ON v.id = se.vehicle_id
GROUP BY v.id, v.vin, v.make, v.model;
```

---

## Common Issues

### ❌ Resource not found

**Error:** `Resource 'ford_pro_api' not found`

**Solution:** Resource name must match exactly (case-sensitive)
- Script expects: `ford_pro_api`
- Your resource: `Ford_Pro_API` ❌
- Fix: Rename to `ford_pro_api` ✅

### ❌ Connection timeout

**Error:** `Connection timeout to database`

**Solution:**
1. Check Railway service is running
2. Verify DATABASE_URL is current (Railway regenerates on redeploy)
3. Update Windmill resource with new URL

### ❌ SSL/TLS errors

**Error:** `SSL connection required`

**Solution:** Add to connection string:
```
?sslmode=require
```

### ❌ Ford Pro authentication failed

**Error:** `401 Unauthorized` from Ford Pro API

**Solution:**
1. Verify credentials in Ford Pro Portal
2. Check if API access is enabled for your account
3. Ensure credentials haven't expired
4. Verify scope includes `vehicle.telematics vehicle.info`

---

## Updating Resources

### Update Resource Values:

1. Windmill → **Resources**
2. Find resource → Click **Edit**
3. Update field values
4. Click **Save**

### Rotate Credentials:

1. Generate new credentials in Ford Pro Portal
2. Update `ford_pro_api` resource in Windmill
3. Test with a manual script run
4. Old credentials can be revoked in Ford Pro Portal

### Update Database Connection:

1. Get new DATABASE_URL from Railway
2. Update `fleet_db` resource in Windmill
3. Test connection
4. All scripts will automatically use new connection

---

## Resource Permissions

### Who can access resources?

- **Default:** All workspace users
- **Restricted:** Set in resource settings → Permissions
- **For production:** Create separate resources for dev/staging/prod

### Best Practices:

1. ✅ Use separate resources per environment
2. ✅ Store secrets in resources (never in code)
3. ✅ Use descriptive names: `ford_pro_api_prod`, `fleet_db_staging`
4. ✅ Document resource purpose in Description field
5. ✅ Test resources after creation
6. ✅ Keep resource names consistent across scripts

---

## Next Steps

After creating resources:
1. ✅ Initialize database: Run `/database/init-fleet-db.sql`
2. ✅ Import scripts: Copy from `/windmill/scripts/`
3. ✅ Import flows: Copy from `/windmill/flows/`
4. ✅ Test sync: Run `ford_pro_sync` script manually
5. ✅ Enable schedule: Activate daily sync flow

See [WINDMILL-SETUP.md](WINDMILL-SETUP.md) for detailed instructions.
