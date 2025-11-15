// Vehicle Assignment Management Script
// Handles employee-vehicle assignments for proper attribution of safety events

import { Resource, type Sql } from "https://deno.land/x/windmill@v1.188.1/mod.ts";

export async function main(
  fleet_db: Resource<Sql>,
  action: 'assign' | 'unassign' | 'list',
  employee_number?: string,
  vehicle_vin?: string,
  is_primary_driver: boolean = false
) {
  switch (action) {
    case 'assign':
      return await assignVehicle(fleet_db, employee_number!, vehicle_vin!, is_primary_driver);
    case 'unassign':
      return await unassignVehicle(fleet_db, employee_number!, vehicle_vin!);
    case 'list':
      return await listAssignments(fleet_db, employee_number, vehicle_vin);
    default:
      throw new Error(`Invalid action: ${action}`);
  }
}

async function assignVehicle(
  db: any,
  employeeNumber: string,
  vehicleVin: string,
  isPrimaryDriver: boolean
) {
  // Get employee ID
  const employeeResult = await db.query(
    `SELECT id, first_name, last_name, department_id 
     FROM employees 
     WHERE employee_number = $1 AND is_active = true`,
    [employeeNumber]
  );
  
  if (employeeResult.rows.length === 0) {
    throw new Error(`Employee ${employeeNumber} not found or inactive`);
  }
  
  const employee = employeeResult.rows[0];
  
  // Get vehicle ID
  const vehicleResult = await db.query(
    `SELECT id, make, model, year, license_plate 
     FROM vehicles 
     WHERE vin = $1 AND is_active = true`,
    [vehicleVin]
  );
  
  if (vehicleResult.rows.length === 0) {
    throw new Error(`Vehicle ${vehicleVin} not found or inactive`);
  }
  
  const vehicle = vehicleResult.rows[0];
  
  // Check if assignment already exists
  const existingAssignment = await db.query(
    `SELECT id, unassigned_date 
     FROM vehicle_assignments 
     WHERE employee_id = $1 AND vehicle_id = $2 AND unassigned_date IS NULL`,
    [employee.id, vehicle.id]
  );
  
  if (existingAssignment.rows.length > 0) {
    return {
      success: false,
      message: `Employee ${employee.first_name} ${employee.last_name} is already assigned to vehicle ${vehicle.make} ${vehicle.model} (${vehicle.license_plate})`
    };
  }
  
  // If marking as primary driver, unset other primary drivers for this vehicle
  if (isPrimaryDriver) {
    await db.query(
      `UPDATE vehicle_assignments 
       SET is_primary_driver = false 
       WHERE vehicle_id = $1 AND unassigned_date IS NULL`,
      [vehicle.id]
    );
  }
  
  // Create new assignment
  const assignmentResult = await db.query(
    `INSERT INTO vehicle_assignments 
     (employee_id, vehicle_id, assigned_date, is_primary_driver)
     VALUES ($1, $2, CURRENT_DATE, $3)
     RETURNING id, assigned_date`,
    [employee.id, vehicle.id, isPrimaryDriver]
  );
  
  const assignment = assignmentResult.rows[0];
  
  // Update vehicle department based on primary driver
  if (isPrimaryDriver && employee.department_id) {
    await db.query(
      `UPDATE vehicles 
       SET department_id = $1 
       WHERE id = $2`,
      [employee.department_id, vehicle.id]
    );
  }
  
  return {
    success: true,
    assignmentId: assignment.id,
    message: `Assigned ${employee.first_name} ${employee.last_name} to ${vehicle.make} ${vehicle.model} (${vehicle.license_plate})`,
    details: {
      employee: `${employee.first_name} ${employee.last_name}`,
      vehicle: `${vehicle.make} ${vehicle.model} ${vehicle.year}`,
      licensePlate: vehicle.license_plate,
      assignedDate: assignment.assigned_date,
      isPrimaryDriver
    }
  };
}

async function unassignVehicle(
  db: any,
  employeeNumber: string,
  vehicleVin: string
) {
  // Get employee ID
  const employeeResult = await db.query(
    `SELECT id, first_name, last_name 
     FROM employees 
     WHERE employee_number = $1`,
    [employeeNumber]
  );
  
  if (employeeResult.rows.length === 0) {
    throw new Error(`Employee ${employeeNumber} not found`);
  }
  
  const employee = employeeResult.rows[0];
  
  // Get vehicle ID
  const vehicleResult = await db.query(
    `SELECT id, make, model, license_plate 
     FROM vehicles 
     WHERE vin = $1`,
    [vehicleVin]
  );
  
  if (vehicleResult.rows.length === 0) {
    throw new Error(`Vehicle ${vehicleVin} not found`);
  }
  
  const vehicle = vehicleResult.rows[0];
  
  // Update assignment
  const updateResult = await db.query(
    `UPDATE vehicle_assignments 
     SET unassigned_date = CURRENT_DATE 
     WHERE employee_id = $1 AND vehicle_id = $2 AND unassigned_date IS NULL
     RETURNING id, assigned_date, unassigned_date`,
    [employee.id, vehicle.id]
  );
  
  if (updateResult.rows.length === 0) {
    return {
      success: false,
      message: `No active assignment found for ${employee.first_name} ${employee.last_name} and vehicle ${vehicle.make} ${vehicle.model}`
    };
  }
  
  const assignment = updateResult.rows[0];
  
  return {
    success: true,
    message: `Unassigned ${employee.first_name} ${employee.last_name} from ${vehicle.make} ${vehicle.model} (${vehicle.license_plate})`,
    details: {
      employee: `${employee.first_name} ${employee.last_name}`,
      vehicle: `${vehicle.make} ${vehicle.model}`,
      assignedDate: assignment.assigned_date,
      unassignedDate: assignment.unassigned_date
    }
  };
}

async function listAssignments(
  db: any,
  employeeNumber?: string,
  vehicleVin?: string
) {
  let query = `
    SELECT 
      va.id,
      e.employee_number,
      e.first_name || ' ' || e.last_name as employee_name,
      e.email,
      d.name as department,
      v.vin,
      v.license_plate,
      v.make || ' ' || v.model || ' ' || v.year as vehicle_description,
      va.assigned_date,
      va.unassigned_date,
      va.is_primary_driver
    FROM vehicle_assignments va
    JOIN employees e ON va.employee_id = e.id
    JOIN vehicles v ON va.vehicle_id = v.id
    LEFT JOIN departments d ON e.department_id = d.id
    WHERE va.unassigned_date IS NULL
  `;
  
  const params: any[] = [];
  
  if (employeeNumber) {
    params.push(employeeNumber);
    query += ` AND e.employee_number = $${params.length}`;
  }
  
  if (vehicleVin) {
    params.push(vehicleVin);
    query += ` AND v.vin = $${params.length}`;
  }
  
  query += ` ORDER BY d.name, e.last_name, e.first_name`;
  
  const result = await db.query(query, params);
  
  return {
    success: true,
    count: result.rows.length,
    assignments: result.rows.map((row: any) => ({
      id: row.id,
      employee: {
        number: row.employee_number,
        name: row.employee_name,
        email: row.email,
        department: row.department
      },
      vehicle: {
        vin: row.vin,
        licensePlate: row.license_plate,
        description: row.vehicle_description
      },
      assignedDate: row.assigned_date,
      isPrimaryDriver: row.is_primary_driver
    }))
  };
}
