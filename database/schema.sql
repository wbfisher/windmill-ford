-- SMSI Fleet Metrics Database Schema
-- Optimized for time-series data with TimescaleDB

-- Enable TimescaleDB extension
CREATE EXTENSION IF NOT EXISTS timescaledb;

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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT no_overlap_assignments EXCLUDE USING gist (
        vehicle_id WITH =,
        daterange(assigned_date, unassigned_date, '[)') WITH &&
    ) WHERE (is_primary_driver = true)
);

-- Safety events table (time-series data)
CREATE TABLE IF NOT EXISTS safety_events (
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
    ford_pro_event_id VARCHAR(100) UNIQUE
);

-- Convert safety_events to hypertable for TimescaleDB optimization
SELECT create_hypertable('safety_events', 'time', if_not_exists => TRUE);

-- Create index for faster queries
CREATE INDEX idx_safety_events_vehicle_time ON safety_events (vehicle_id, time DESC);
CREATE INDEX idx_safety_events_employee_time ON safety_events (employee_id, time DESC);
CREATE INDEX idx_safety_events_type_time ON safety_events (event_type, time DESC);

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

-- Create indexes for performance
CREATE INDEX idx_vehicle_assignments_employee ON vehicle_assignments(employee_id);
CREATE INDEX idx_vehicle_assignments_vehicle ON vehicle_assignments(vehicle_id);
CREATE INDEX idx_daily_scores_date ON daily_driver_scores(date DESC);
CREATE INDEX idx_daily_scores_employee ON daily_driver_scores(employee_id, date DESC);
CREATE INDEX idx_dept_scores_date ON department_daily_scores(date DESC);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add triggers for updated_at
CREATE TRIGGER update_departments_updated_at BEFORE UPDATE ON departments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_employees_updated_at BEFORE UPDATE ON employees
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_vehicles_updated_at BEFORE UPDATE ON vehicles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Sample data for testing (remove in production)
INSERT INTO departments (name, manager_email) VALUES 
    ('HVAC', 'hvac.manager@smsi.com'),
    ('Electrical', 'electrical.manager@smsi.com'),
    ('Plumbing', 'plumbing.manager@smsi.com'),
    ('Mechanical', 'mechanical.manager@smsi.com');

-- Compression policy for TimescaleDB (compress data older than 30 days)
SELECT add_compression_policy('safety_events', INTERVAL '30 days', if_not_exists => TRUE);
