-- =============================================================================
-- Industrial IoT OPC UA Database Setup Script
-- =============================================================================
-- This script sets up the PostgreSQL database for OPC UA data collection
-- Run this script as postgres superuser if automatic creation fails

-- Create database (if not exists)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'OpcUaDb') THEN
        PERFORM dblink_exec('dbname=postgres', 'CREATE DATABASE "OpcUaDb"');
    END IF;
END
$$;

-- Connect to OpcUaDb database
\c OpcUaDb;

-- Create main data table
CREATE TABLE IF NOT EXISTS opc_live_data (
    id SERIAL PRIMARY KEY,
    node_id VARCHAR(200) NOT NULL,
    display_name VARCHAR(200),
    value TEXT,
    data_type VARCHAR(50),
    timestamp TIMESTAMP DEFAULT NOW(),
    quality VARCHAR(50),
    server_timestamp TIMESTAMP,
    
    -- Additional metadata
    namespace_uri VARCHAR(500),
    browse_name VARCHAR(200),
    unit_of_measure VARCHAR(50),
    min_value DECIMAL(15,6),
    max_value DECIMAL(15,6),
    
    -- Indexing for performance
    CONSTRAINT unique_node_timestamp UNIQUE (node_id, timestamp)
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_opc_timestamp ON opc_live_data(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_opc_node_id ON opc_live_data(node_id);
CREATE INDEX IF NOT EXISTS idx_opc_display_name ON opc_live_data(display_name);
CREATE INDEX IF NOT EXISTS idx_opc_data_type ON opc_live_data(data_type);
CREATE INDEX IF NOT EXISTS idx_opc_quality ON opc_live_data(quality);

-- Create composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_opc_node_time ON opc_live_data(node_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_opc_display_time ON opc_live_data(display_name, timestamp DESC);

-- Create table for OPC UA server information
CREATE TABLE IF NOT EXISTS opc_servers (
    id SERIAL PRIMARY KEY,
    server_name VARCHAR(200) NOT NULL,
    endpoint_url VARCHAR(500) NOT NULL UNIQUE,
    server_uri VARCHAR(500),
    product_name VARCHAR(200),
    product_version VARCHAR(100),
    last_connected TIMESTAMP DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE,
    connection_status VARCHAR(50) DEFAULT 'Unknown',
    certificate_thumbprint VARCHAR(100)
);

-- Create table for node metadata
CREATE TABLE IF NOT EXISTS opc_nodes (
    id SERIAL PRIMARY KEY,
    server_id INTEGER REFERENCES opc_servers(id),
    node_id VARCHAR(200) NOT NULL,
    display_name VARCHAR(200),
    browse_name VARCHAR(200),
    node_class VARCHAR(50),
    data_type VARCHAR(100),
    access_level INTEGER,
    user_access_level INTEGER,
    namespace_index INTEGER,
    namespace_uri VARCHAR(500),
    description TEXT,
    is_monitored BOOLEAN DEFAULT FALSE,
    sampling_interval INTEGER DEFAULT 1000,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT unique_server_node UNIQUE (server_id, node_id)
);

-- Create table for alarms and events
CREATE TABLE IF NOT EXISTS opc_alarms (
    id SERIAL PRIMARY KEY,
    server_id INTEGER REFERENCES opc_servers(id),
    source_node VARCHAR(200),
    alarm_type VARCHAR(100),
    severity INTEGER,
    message TEXT,
    condition_name VARCHAR(200),
    active_state BOOLEAN,
    acknowledged BOOLEAN DEFAULT FALSE,
    event_time TIMESTAMP,
    receive_time TIMESTAMP DEFAULT NOW(),
    retain BOOLEAN DEFAULT FALSE
);

-- Create table for historical data (partitioned by date)
CREATE TABLE IF NOT EXISTS opc_historical_data (
    id BIGSERIAL,
    node_id VARCHAR(200) NOT NULL,
    display_name VARCHAR(200),
    value TEXT,
    data_type VARCHAR(50),
    timestamp TIMESTAMP NOT NULL,
    quality VARCHAR(50),
    server_timestamp TIMESTAMP,
    archive_date DATE GENERATED ALWAYS AS (DATE(timestamp)) STORED,
    
    PRIMARY KEY (id, archive_date)
) PARTITION BY RANGE (archive_date);

-- Create partitions for current year
DO $$
DECLARE
    start_date DATE := DATE_TRUNC('year', CURRENT_DATE);
    end_date DATE;
    partition_name TEXT;
    year_val INTEGER;
BEGIN
    FOR year_val IN EXTRACT(YEAR FROM CURRENT_DATE)..(EXTRACT(YEAR FROM CURRENT_DATE) + 1) LOOP
        start_date := MAKE_DATE(year_val, 1, 1);
        end_date := MAKE_DATE(year_val + 1, 1, 1);
        partition_name := 'opc_historical_data_y' || year_val;
        
        EXECUTE format('CREATE TABLE IF NOT EXISTS %I PARTITION OF opc_historical_data 
                       FOR VALUES FROM (%L) TO (%L)', 
                       partition_name, start_date, end_date);
    END LOOP;
END $$;

-- Create views for easier data access
CREATE OR REPLACE VIEW v_latest_opc_data AS
SELECT DISTINCT ON (node_id) 
    node_id,
    display_name,
    value,
    data_type,
    timestamp,
    quality,
    server_timestamp
FROM opc_live_data 
ORDER BY node_id, timestamp DESC;

CREATE OR REPLACE VIEW v_active_alarms AS
SELECT 
    a.*,
    s.server_name,
    s.endpoint_url
FROM opc_alarms a
JOIN opc_servers s ON a.server_id = s.id
WHERE a.active_state = TRUE 
  AND a.acknowledged = FALSE
ORDER BY a.severity DESC, a.event_time DESC;

-- Create functions for data management
CREATE OR REPLACE FUNCTION clean_old_data(days_to_keep INTEGER DEFAULT 30)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM opc_live_data 
    WHERE timestamp < NOW() - INTERVAL '1 day' * days_to_keep;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    INSERT INTO opc_live_data (node_id, display_name, value, data_type, quality)
    VALUES ('system', 'data_cleanup', deleted_count::TEXT, 'Integer', 'Good');
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Create function to archive old data
CREATE OR REPLACE FUNCTION archive_old_data(days_old INTEGER DEFAULT 7)
RETURNS INTEGER AS $$
DECLARE
    archived_count INTEGER;
BEGIN
    INSERT INTO opc_historical_data 
        (node_id, display_name, value, data_type, timestamp, quality, server_timestamp)
    SELECT 
        node_id, display_name, value, data_type, timestamp, quality, server_timestamp
    FROM opc_live_data 
    WHERE timestamp < NOW() - INTERVAL '1 day' * days_old;
    
    GET DIAGNOSTICS archived_count = ROW_COUNT;
    
    DELETE FROM opc_live_data 
    WHERE timestamp < NOW() - INTERVAL '1 day' * days_old;
    
    RETURN archived_count;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for automatic timestamping
CREATE OR REPLACE FUNCTION update_modified_time()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_opc_nodes_updated_at
    BEFORE UPDATE ON opc_nodes
    FOR EACH ROW
    EXECUTE FUNCTION update_modified_time();

-- Insert default server configuration
INSERT INTO opc_servers (server_name, endpoint_url, server_uri, product_name, is_active)
VALUES 
    ('Prosys Simulation Server', 'opc.tcp://localhost:53530/OPCUA/SimulationServer', 'urn:ProsysSampleServer', 'Prosys OPC UA Simulation Server', TRUE),
    ('Local OPC Server', 'opc.tcp://127.0.0.1:4840/OPCUA/Server', 'urn:LocalOPCServer', 'Local Development Server', FALSE)
ON CONFLICT (endpoint_url) DO NOTHING;

-- Grant permissions (adjust as needed for your security requirements)
-- CREATE USER opcua_app WITH PASSWORD 'secure_password_here';
-- GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO opcua_app;
-- GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO opcua_app;

-- Create maintenance schedule (examples)
COMMENT ON FUNCTION clean_old_data(INTEGER) IS 'Removes data older than specified days. Call daily via cron job.';
COMMENT ON FUNCTION archive_old_data(INTEGER) IS 'Archives data older than specified days to historical table.';

-- Performance analysis queries (for monitoring)
COMMENT ON TABLE opc_live_data IS 'Main table for real-time OPC UA data collection';
COMMENT ON TABLE opc_historical_data IS 'Partitioned table for long-term data storage';
COMMENT ON TABLE opc_servers IS 'OPC UA server connection registry';
COMMENT ON TABLE opc_nodes IS 'OPC UA node metadata and configuration';
COMMENT ON TABLE opc_alarms IS 'OPC UA alarms and events log';

-- Sample maintenance queries
/*
-- Daily maintenance (run via cron):
SELECT clean_old_data(30);  -- Keep 30 days of live data
SELECT archive_old_data(7); -- Archive data older than 7 days

-- Performance monitoring:
SELECT COUNT(*) as total_records, 
       MAX(timestamp) as latest_data,
       MIN(timestamp) as oldest_data
FROM opc_live_data;

-- Top data producers:
SELECT display_name, COUNT(*) as record_count
FROM opc_live_data 
WHERE timestamp > NOW() - INTERVAL '1 hour'
GROUP BY display_name 
ORDER BY record_count DESC;
*/

PRINT 'Database setup completed successfully!';
PRINT 'Tables created: opc_live_data, opc_servers, opc_nodes, opc_alarms, opc_historical_data';
PRINT 'Views created: v_latest_opc_data, v_active_alarms';
PRINT 'Functions created: clean_old_data(), archive_old_data()';