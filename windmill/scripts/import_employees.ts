// Employee Import Script for Windmill
// Imports employees from CSV format

import { Resource, type Sql } from "https://deno.land/x/windmill@v1.188.1/mod.ts";
import { parse } from "https://deno.land/std@0.195.0/csv/mod.ts";

export async function main(
  fleet_db: Resource<Sql>,
  csv_content: string,
  department_mapping: Record<string, number> = {
    "HVAC": 1,
    "Electrical": 2,
    "Plumbing": 3,
    "Mechanical": 4
  }
) {
  console.log("Starting employee import...");
  
  // Parse CSV
  const records = parse(csv_content, {
    skipFirstRow: true,
    columns: ["employee_number", "first_name", "last_name", "email", "department"]
  });
  
  let imported = 0;
  let skipped = 0;
  let errors = [];
  
  for (const record of records) {
    try {
      // Skip empty rows
      if (!record.employee_number || !record.first_name || !record.last_name) {
        skipped++;
        continue;
      }
      
      // Get department ID
      const deptId = department_mapping[record.department] || null;
      
      if (record.department && !deptId) {
        console.warn(`Unknown department: ${record.department} for employee ${record.employee_number}`);
      }
      
      // Insert or update employee
      const result = await fleet_db.query(
        `INSERT INTO employees (employee_number, first_name, last_name, email, department_id)
         VALUES ($1, $2, $3, $4, $5)
         ON CONFLICT (employee_number)
         DO UPDATE SET
           first_name = $2,
           last_name = $3,
           email = $4,
           department_id = $5,
           updated_at = CURRENT_TIMESTAMP
         RETURNING id`,
        [
          record.employee_number,
          record.first_name,
          record.last_name,
          record.email || null,
          deptId
        ]
      );
      
      imported++;
      console.log(`Imported: ${record.first_name} ${record.last_name} (${record.employee_number})`);
      
    } catch (error) {
      errors.push({
        employee: record.employee_number,
        error: error.message
      });
      console.error(`Failed to import ${record.employee_number}:`, error.message);
    }
  }
  
  // Summary
  const summary = {
    total_rows: records.length,
    imported: imported,
    skipped: skipped,
    errors: errors.length,
    error_details: errors
  };
  
  console.log("\n=== Import Summary ===");
  console.log(`Total rows: ${summary.total_rows}`);
  console.log(`Successfully imported: ${summary.imported}`);
  console.log(`Skipped (empty): ${summary.skipped}`);
  console.log(`Errors: ${summary.errors}`);
  
  return summary;
}

/* 
Example CSV format:
employee_number,first_name,last_name,email,department
EMP001,John,Smith,jsmith@smsi.com,HVAC
EMP002,Jane,Doe,jdoe@smsi.com,Electrical
EMP003,Bob,Johnson,bjohnson@smsi.com,Plumbing
*/
