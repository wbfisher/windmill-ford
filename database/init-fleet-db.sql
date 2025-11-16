-- Fleet Database Initialization Script
-- Run this on your Railway fleet-db PostgreSQL instance
-- This creates all tables needed for the Ford Pro integration

-- Note: TimescaleDB extension is optional. If not available, tables will work as regular PostgreSQL tables.
-- Try to enable TimescaleDB, but continue if it fails
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS timescaledb;
    RAISE NOTICE 'TimescaleDB extension enabled';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'TimescaleDB not available - using regular PostgreSQL tables';
END
$$;

-- Departments table
CREATE TABLE IF NOT EXISTS departments (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    manager_email VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Employees table
CREATE TABLE IF NOT EXISTS employees (
    id SERIAL PRIMARY KEY,
    employee_number VARCHAR(50) UNIQUE NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE,
    department_id INTEGER REFERENCES departments(id),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Vehicles table
CREATE TABLE IF NOT EXISTS vehicles (
    id SERIAL PRIMARY KEY,
    vin VARCHAR(17) UNIQUE NOT NULL,
    ford_pro_id VARCHAR(100) UNIQUE,
    make VARCHAR(50),
    model VARCHAR(50),
    year INTEGER,
    license_plate VARCHAR(20),
    department_id INTEGER REFERENCES departments(id),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Vehicle assignments (many-to-many with history)
CREATE TABLE IF NOT EXISTS vehicle_assignments (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER REFERENCES employees(id),
    vehicle_id INTEGER REFERENCES vehicles(id),
    assigned_date DATE NOT NULL,
    unassigned_date DATE,
    is_primary_driver BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Safety events table (time-series data)
CREATE TABLE IF NOT EXISTS safety_events (
    id SERIAL,
    time TIMESTAMP WITH TIME ZONE NOT NULL,
    vehicle_id INTEGER REFERENCES vehicles(id),
    employee_id INTEGER REFERENCES employees(id),
    event_type VARCHAR(50) NOT NULL, -- harsh_brake, rapid_accel, speeding, seatbelt_off, collision
    severity VARCHAR(20), -- low, medium, high, critical
    speed_mph DECIMAL(5,2),
    location_lat DECIMAL(10, 8),
    location_lon DECIMAL(11, 8),
    location_address TEXT,
    duration_seconds INTEGER,
    metadata JSONB,
    ford_pro_event_id VARCHAR(100) UNIQUE,
    PRIMARY KEY (id, time)
);

-- Try to convert safety_events to hypertable if TimescaleDB is available
DO $$
BEGIN
    PERFORM create_hypertable('safety_events', 'time', if_not_exists => TRUE);
    RAISE NOTICE 'Created TimescaleDB hypertable for safety_events';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Using regular table for safety_events (TimescaleDB not available)';
END
$$;

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_safety_events_vehicle_time ON safety_events (vehicle_id, time DESC);
CREATE INDEX IF NOT EXISTS idx_safety_events_employee_time ON safety_events (employee_id, time DESC);
CREATE INDEX IF NOT EXISTS idx_safety_events_type_time ON safety_events (event_type, time DESC);

-- Daily driver scores (aggregated data)
CREATE TABLE IF NOT EXISTS daily_driver_scores (
    date DATE NOT NULL,
    employee_id INTEGER REFERENCES employees(id),
    vehicle_id INTEGER REFERENCES vehicles(id),
    miles_driven DECIMAL(10,2),
    total_events INTEGER DEFAULT 0,
    harsh_brake_count INTEGER DEFAULT 0,
    rapid_accel_count INTEGER DEFAULT 0,
    speeding_count INTEGER DEFAULT 0,
    seatbelt_off_count INTEGER DEFAULT 0,
    -- Scores (0-100, higher is better)
    overall_score DECIMAL(5,2),
    brake_score DECIMAL(5,2),
    acceleration_score DECIMAL(5,2),
    speed_score DECIMAL(5,2),
    seatbelt_score DECIMAL(5,2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (date, employee_id, vehicle_id)
);

-- Department daily rollup
CREATE TABLE IF NOT EXISTS department_daily_scores (
    date DATE NOT NULL,
    department_id INTEGER REFERENCES departments(id),
    active_drivers INTEGER,
    total_miles DECIMAL(10,2),
    avg_overall_score DECIMAL(5,2),
    avg_brake_score DECIMAL(5,2),
    avg_acceleration_score DECIMAL(5,2),
    avg_speed_score DECIMAL(5,2),
    avg_seatbelt_score DECIMAL(5,2),
    high_risk_drivers INTEGER DEFAULT 0, -- score < 70
    medium_risk_drivers INTEGER DEFAULT 0, -- score 70-85
    low_risk_drivers INTEGER DEFAULT 0, -- score > 85
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (date, department_id)
);

-- Sync log for tracking Ford Pro API pulls
CREATE TABLE IF NOT EXISTS sync_log (
    id SERIAL PRIMARY KEY,
    sync_type VARCHAR(50), -- 'full', 'incremental', 'manual'
    status VARCHAR(20), -- 'started', 'completed', 'failed'
    started_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE,
    records_processed INTEGER DEFAULT 0,
    error_message TEXT,
    metadata JSONB
);

-- Views for easier reporting

-- Current vehicle assignments
CREATE OR REPLACE VIEW current_vehicle_assignments AS
SELECT
    va.id,
    e.employee_number,
    e.first_name || ' ' || e.last_name AS employee_name,
    e.email,
    d.name AS department,
    v.vin,
    v.license_plate,
    v.make || ' ' || v.model || ' ' || v.year AS vehicle_description,
    va.assigned_date,
    va.is_primary_driver
FROM vehicle_assignments va
JOIN employees e ON va.employee_id = e.id
JOIN vehicles v ON va.vehicle_id = v.id
LEFT JOIN departments d ON e.department_id = d.id
WHERE va.unassigned_date IS NULL
  AND e.is_active = true
  AND v.is_active = true;

-- Monthly driver summary
CREATE OR REPLACE VIEW monthly_driver_summary AS
SELECT
    DATE_TRUNC('month', date) AS month,
    employee_id,
    COUNT(DISTINCT vehicle_id) AS vehicles_driven,
    SUM(miles_driven) AS total_miles,
    AVG(overall_score) AS avg_score,
    SUM(harsh_brake_count + rapid_accel_count + speeding_count + seatbelt_off_count) AS total_events
FROM daily_driver_scores
GROUP BY DATE_TRUNC('month', date), employee_id;

-- Create additional indexes for performance
CREATE INDEX IF NOT EXISTS idx_vehicle_assignments_employee ON vehicle_assignments(employee_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_assignments_vehicle ON vehicle_assignments(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_daily_scores_date ON daily_driver_scores(date DESC);
CREATE INDEX IF NOT EXISTS idx_daily_scores_employee ON daily_driver_scores(employee_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_dept_scores_date ON department_daily_scores(date DESC);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add triggers for updated_at
DROP TRIGGER IF EXISTS update_departments_updated_at ON departments;
CREATE TRIGGER update_departments_updated_at BEFORE UPDATE ON departments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_employees_updated_at ON employees;
CREATE TRIGGER update_employees_updated_at BEFORE UPDATE ON employees
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_vehicles_updated_at ON vehicles;
CREATE TRIGGER update_vehicles_updated_at BEFORE UPDATE ON vehicles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert sample departments for testing
INSERT INTO departments (name, manager_email) VALUES
    ('HVAC', 'hvac.manager@smsi.com'),
    ('Electrical', 'electrical.manager@smsi.com'),
    ('Plumbing', 'plumbing.manager@smsi.com'),
    ('Mechanical', 'mechanical.manager@smsi.com')
ON CONFLICT (name) DO NOTHING;

-- Try to enable compression policy for TimescaleDB (optional)
DO $$
BEGIN
    PERFORM add_compression_policy('safety_events', INTERVAL '30 days', if_not_exists => TRUE);
    RAISE NOTICE 'Added compression policy for safety_events';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Compression not available (TimescaleDB feature)';
END
$$;

-- Verify installation
DO $$
DECLARE
    table_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO table_count
    FROM information_schema.tables
    WHERE table_schema = 'public'
    AND table_name IN ('departments', 'employees', 'vehicles', 'vehicle_assignments',
                       'safety_events', 'daily_driver_scores', 'department_daily_scores', 'sync_log');

    RAISE NOTICE '======================================';
    RAISE NOTICE 'Fleet Database Initialization Complete!';
    RAISE NOTICE 'Created % tables', table_count;
    RAISE NOTICE '======================================';

    -- Show table sizes
    RAISE NOTICE 'Table Status:';
    RAISE NOTICE '  departments: %', (SELECT COUNT(*) FROM departments);
    RAISE NOTICE '  employees: %', (SELECT COUNT(*) FROM employees);
    RAISE NOTICE '  vehicles: %', (SELECT COUNT(*) FROM vehicles);
    RAISE NOTICE '  vehicle_assignments: %', (SELECT COUNT(*) FROM vehicle_assignments);
    RAISE NOTICE '  safety_events: %', (SELECT COUNT(*) FROM safety_events);
    RAISE NOTICE '  sync_log: %', (SELECT COUNT(*) FROM sync_log);
    RAISE NOTICE '======================================';
END
$$;
