// Ford Pro Telematics Sync Script for Windmill
// Fetches safety events and driver behavior data from Ford Pro API

import { Resource, type Sql } from "https://deno.land/x/windmill@v1.188.1/mod.ts";

// Type definitions for Ford Pro API
interface FordProToken {
  access_token: string;
  token_type: string;
  expires_in: number;
}

interface FordProVehicle {
  vehicleId: string;
  vin: string;
  make: string;
  model: string;
  year: number;
  licensePlate?: string;
}

interface FordProSafetyEvent {
  eventId: string;
  vehicleId: string;
  timestamp: string;
  eventType: 'HARSH_BRAKE' | 'RAPID_ACCELERATION' | 'SPEEDING' | 'SEATBELT_OFF' | 'COLLISION_ALERT';
  severity: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
  location?: {
    latitude: number;
    longitude: number;
    address?: string;
  };
  speed?: number;
  duration?: number;
  metadata?: Record<string, any>;
}

interface FordProDriverBehavior {
  vehicleId: string;
  date: string;
  milesDriven: number;
  harshBrakeCount: number;
  rapidAccelCount: number;
  speedingCount: number;
  seatbeltOffCount: number;
  overallScore: number;
}

export async function main(
  // Windmill automatically injects these from Resources
  ford_pro_api: Resource<{
    client_id: string;
    client_secret: string;
    fleet_id: string;
    api_base_url?: string;
  }>,
  fleet_db: Resource<Sql>,
  sync_type: 'full' | 'incremental' | 'manual' = 'incremental',
  days_to_sync: number = 7
) {
  console.log(`Starting ${sync_type} sync for last ${days_to_sync} days`);
  
  // Log sync start
  const syncLogResult = await fleet_db.query(
    `INSERT INTO sync_log (sync_type, status, metadata) 
     VALUES ($1, 'started', $2) 
     RETURNING id`,
    [sync_type, { days_to_sync }]
  );
  const syncLogId = syncLogResult.rows[0].id;

  try {
    // Get Ford Pro API token
    const token = await getFordProToken(ford_pro_api);
    
    // Set date range for sync
    const endDate = new Date();
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days_to_sync);
    
    // Fetch vehicles from Ford Pro
    const vehicles = await fetchVehicles(ford_pro_api, token);
    console.log(`Found ${vehicles.length} vehicles`);
    
    // Sync vehicles to database
    await syncVehiclesToDB(fleet_db, vehicles);
    
    let totalEventsProcessed = 0;
    
    // For each vehicle, fetch safety events and driver behavior
    for (const vehicle of vehicles) {
      console.log(`Processing vehicle ${vehicle.vin}`);
      
      // Get vehicle ID from database
      const vehicleResult = await fleet_db.query(
        `SELECT id FROM vehicles WHERE vin = $1`,
        [vehicle.vin]
      );
      
      if (vehicleResult.rows.length === 0) {
        console.warn(`Vehicle ${vehicle.vin} not found in database`);
        continue;
      }
      
      const vehicleDbId = vehicleResult.rows[0].id;
      
      // Fetch safety events
      const events = await fetchSafetyEvents(
        ford_pro_api,
        token,
        vehicle.vehicleId,
        startDate,
        endDate
      );
      
      // Process and store events
      for (const event of events) {
        await processSafetyEvent(fleet_db, event, vehicleDbId);
        totalEventsProcessed++;
      }
      
      // Fetch and store driver behavior scores
      const behaviorData = await fetchDriverBehavior(
        ford_pro_api,
        token,
        vehicle.vehicleId,
        startDate,
        endDate
      );
      
      await processDriverBehavior(fleet_db, behaviorData, vehicleDbId);
    }
    
    // Calculate daily scores for all drivers
    await calculateDailyScores(fleet_db, startDate, endDate);
    
    // Calculate department rollups
    await calculateDepartmentScores(fleet_db, startDate, endDate);
    
    // Mark sync as completed
    await fleet_db.query(
      `UPDATE sync_log 
       SET status = 'completed', 
           completed_at = CURRENT_TIMESTAMP, 
           records_processed = $1
       WHERE id = $2`,
      [totalEventsProcessed, syncLogId]
    );
    
    console.log(`Sync completed. Processed ${totalEventsProcessed} events.`);
    return {
      success: true,
      eventsProcessed: totalEventsProcessed,
      vehiclesProcessed: vehicles.length
    };
    
  } catch (error) {
    // Log error
    await fleet_db.query(
      `UPDATE sync_log 
       SET status = 'failed', 
           completed_at = CURRENT_TIMESTAMP, 
           error_message = $1
       WHERE id = $2`,
      [error.message, syncLogId]
    );
    
    throw error;
  }
}

// Helper function to get Ford Pro API token
async function getFordProToken(config: any): Promise<string> {
  const baseUrl = config.api_base_url || 'https://api.fordpro.com';
  
  const response = await fetch(`${baseUrl}/oauth/token`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      grant_type: 'client_credentials',
      client_id: config.client_id,
      client_secret: config.client_secret,
      scope: 'vehicle.telematics vehicle.info'
    })
  });
  
  if (!response.ok) {
    throw new Error(`Failed to get Ford Pro token: ${response.statusText}`);
  }
  
  const data: FordProToken = await response.json();
  return data.access_token;
}

// Fetch vehicles from Ford Pro
async function fetchVehicles(config: any, token: string): Promise<FordProVehicle[]> {
  const baseUrl = config.api_base_url || 'https://api.fordpro.com';
  
  const response = await fetch(`${baseUrl}/v1/fleets/${config.fleet_id}/vehicles`, {
    headers: {
      'Authorization': `Bearer ${token}`,
      'Accept': 'application/json'
    }
  });
  
  if (!response.ok) {
    throw new Error(`Failed to fetch vehicles: ${response.statusText}`);
  }
  
  const data = await response.json();
  return data.vehicles || [];
}

// Sync vehicles to database
async function syncVehiclesToDB(db: any, vehicles: FordProVehicle[]) {
  for (const vehicle of vehicles) {
    await db.query(
      `INSERT INTO vehicles (vin, ford_pro_id, make, model, year, license_plate)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (vin) 
       DO UPDATE SET 
         ford_pro_id = $2,
         make = $3,
         model = $4,
         year = $5,
         license_plate = $6,
         updated_at = CURRENT_TIMESTAMP`,
      [vehicle.vin, vehicle.vehicleId, vehicle.make, vehicle.model, vehicle.year, vehicle.licensePlate]
    );
  }
}

// Fetch safety events for a vehicle
async function fetchSafetyEvents(
  config: any,
  token: string,
  vehicleId: string,
  startDate: Date,
  endDate: Date
): Promise<FordProSafetyEvent[]> {
  const baseUrl = config.api_base_url || 'https://api.fordpro.com';
  
  const response = await fetch(
    `${baseUrl}/v1/vehicles/${vehicleId}/safety-events?` +
    `startDate=${startDate.toISOString()}&endDate=${endDate.toISOString()}`,
    {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Accept': 'application/json'
      }
    }
  );
  
  if (!response.ok) {
    console.warn(`Failed to fetch safety events for ${vehicleId}: ${response.statusText}`);
    return [];
  }
  
  const data = await response.json();
  return data.events || [];
}

// Process and store safety event
async function processSafetyEvent(db: any, event: FordProSafetyEvent, vehicleDbId: number) {
  // Get employee assignment for this vehicle at event time
  const assignmentResult = await db.query(
    `SELECT employee_id 
     FROM vehicle_assignments 
     WHERE vehicle_id = $1 
       AND assigned_date <= $2::date
       AND (unassigned_date IS NULL OR unassigned_date > $2::date)
     ORDER BY is_primary_driver DESC
     LIMIT 1`,
    [vehicleDbId, event.timestamp]
  );
  
  const employeeId = assignmentResult.rows[0]?.employee_id || null;
  
  // Map event type to our schema
  const eventTypeMap = {
    'HARSH_BRAKE': 'harsh_brake',
    'RAPID_ACCELERATION': 'rapid_accel',
    'SPEEDING': 'speeding',
    'SEATBELT_OFF': 'seatbelt_off',
    'COLLISION_ALERT': 'collision'
  };
  
  await db.query(
    `INSERT INTO safety_events 
     (time, vehicle_id, employee_id, event_type, severity, speed_mph, 
      location_lat, location_lon, location_address, duration_seconds, 
      metadata, ford_pro_event_id)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
     ON CONFLICT (ford_pro_event_id) DO NOTHING`,
    [
      event.timestamp,
      vehicleDbId,
      employeeId,
      eventTypeMap[event.eventType],
      event.severity?.toLowerCase(),
      event.speed,
      event.location?.latitude,
      event.location?.longitude,
      event.location?.address,
      event.duration,
      JSON.stringify(event.metadata || {}),
      event.eventId
    ]
  );
}

// Fetch driver behavior data
async function fetchDriverBehavior(
  config: any,
  token: string,
  vehicleId: string,
  startDate: Date,
  endDate: Date
): Promise<FordProDriverBehavior[]> {
  const baseUrl = config.api_base_url || 'https://api.fordpro.com';
  
  const response = await fetch(
    `${baseUrl}/v1/vehicles/${vehicleId}/driver-behavior?` +
    `startDate=${startDate.toISOString()}&endDate=${endDate.toISOString()}`,
    {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Accept': 'application/json'
      }
    }
  );
  
  if (!response.ok) {
    console.warn(`Failed to fetch driver behavior for ${vehicleId}: ${response.statusText}`);
    return [];
  }
  
  const data = await response.json();
  return data.dailyBehavior || [];
}

// Process driver behavior data
async function processDriverBehavior(db: any, behaviorData: FordProDriverBehavior[], vehicleDbId: number) {
  for (const behavior of behaviorData) {
    // Get employee assignment for this date
    const assignmentResult = await db.query(
      `SELECT employee_id 
       FROM vehicle_assignments 
       WHERE vehicle_id = $1 
         AND assigned_date <= $2::date
         AND (unassigned_date IS NULL OR unassigned_date > $2::date)
       ORDER BY is_primary_driver DESC
       LIMIT 1`,
      [vehicleDbId, behavior.date]
    );
    
    const employeeId = assignmentResult.rows[0]?.employee_id || null;
    
    if (!employeeId) continue;
    
    // Calculate individual scores (100 - penalty)
    const brakeScore = Math.max(0, 100 - (behavior.harshBrakeCount * 10));
    const accelScore = Math.max(0, 100 - (behavior.rapidAccelCount * 10));
    const speedScore = Math.max(0, 100 - (behavior.speedingCount * 15));
    const seatbeltScore = behavior.seatbeltOffCount > 0 ? 0 : 100;
    
    await db.query(
      `INSERT INTO daily_driver_scores 
       (date, employee_id, vehicle_id, miles_driven, total_events,
        harsh_brake_count, rapid_accel_count, speeding_count, seatbelt_off_count,
        overall_score, brake_score, acceleration_score, speed_score, seatbelt_score)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
       ON CONFLICT (date, employee_id, vehicle_id)
       DO UPDATE SET
         miles_driven = $4,
         total_events = $5,
         harsh_brake_count = $6,
         rapid_accel_count = $7,
         speeding_count = $8,
         seatbelt_off_count = $9,
         overall_score = $10,
         brake_score = $11,
         acceleration_score = $12,
         speed_score = $13,
         seatbelt_score = $14`,
      [
        behavior.date,
        employeeId,
        vehicleDbId,
        behavior.milesDriven,
        behavior.harshBrakeCount + behavior.rapidAccelCount + behavior.speedingCount + behavior.seatbeltOffCount,
        behavior.harshBrakeCount,
        behavior.rapidAccelCount,
        behavior.speedingCount,
        behavior.seatbeltOffCount,
        behavior.overallScore || (brakeScore + accelScore + speedScore + seatbeltScore) / 4,
        brakeScore,
        accelScore,
        speedScore,
        seatbeltScore
      ]
    );
  }
}

// Calculate daily scores for drivers
async function calculateDailyScores(db: any, startDate: Date, endDate: Date) {
  // This would contain more complex scoring logic
  // For now, scores are calculated in processDriverBehavior
  console.log('Daily scores calculated');
}

// Calculate department rollups
async function calculateDepartmentScores(db: any, startDate: Date, endDate: Date) {
  await db.query(
    `INSERT INTO department_daily_scores 
     (date, department_id, active_drivers, total_miles, 
      avg_overall_score, avg_brake_score, avg_acceleration_score, 
      avg_speed_score, avg_seatbelt_score, 
      high_risk_drivers, medium_risk_drivers, low_risk_drivers)
     SELECT 
       dds.date,
       e.department_id,
       COUNT(DISTINCT dds.employee_id) as active_drivers,
       SUM(dds.miles_driven) as total_miles,
       AVG(dds.overall_score) as avg_overall_score,
       AVG(dds.brake_score) as avg_brake_score,
       AVG(dds.acceleration_score) as avg_acceleration_score,
       AVG(dds.speed_score) as avg_speed_score,
       AVG(dds.seatbelt_score) as avg_seatbelt_score,
       SUM(CASE WHEN dds.overall_score < 70 THEN 1 ELSE 0 END) as high_risk_drivers,
       SUM(CASE WHEN dds.overall_score >= 70 AND dds.overall_score < 85 THEN 1 ELSE 0 END) as medium_risk_drivers,
       SUM(CASE WHEN dds.overall_score >= 85 THEN 1 ELSE 0 END) as low_risk_drivers
     FROM daily_driver_scores dds
     JOIN employees e ON dds.employee_id = e.id
     WHERE dds.date >= $1 AND dds.date <= $2
       AND e.department_id IS NOT NULL
     GROUP BY dds.date, e.department_id
     ON CONFLICT (date, department_id)
     DO UPDATE SET
       active_drivers = EXCLUDED.active_drivers,
       total_miles = EXCLUDED.total_miles,
       avg_overall_score = EXCLUDED.avg_overall_score,
       avg_brake_score = EXCLUDED.avg_brake_score,
       avg_acceleration_score = EXCLUDED.avg_acceleration_score,
       avg_speed_score = EXCLUDED.avg_speed_score,
       avg_seatbelt_score = EXCLUDED.avg_seatbelt_score,
       high_risk_drivers = EXCLUDED.high_risk_drivers,
       medium_risk_drivers = EXCLUDED.medium_risk_drivers,
       low_risk_drivers = EXCLUDED.low_risk_drivers`,
    [startDate, endDate]
  );
  
  console.log('Department scores calculated');
}
