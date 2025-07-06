Connection Settings
PostgreSQL Configuration

// Master database connection (for database creation)
var masterConnectionString = "Host=localhost;Port=5432;Database=postgres;Username=postgres;Password=postgres123";

// Application database connection
var connectionString = "Host=localhost;Port=5432;Database=OpcUaDb;Username=postgres;Password=postgres123";

// Alternative configurations:
// Remote server: "Host=192.168.1.100;Port=5432;Database=OpcUaDb;Username=opcuser;Password=securepass123"
// SSL enabled: "Host=localhost;Port=5432;Database=OpcUaDb;Username=postgres;Password=postgres123;SSL Mode=Require"
OPC UA Server Configuration
csharp// Local simulator
var endpointUrl = "opc.tcp://localhost:53530/OPCUA/SimulationServer";

// Remote server
var endpointUrl = "opc.tcp://192.168.1.50:4840/OPCUA/ProductionServer";

// With security
var endpointUrl = "opc.tcp://server.company.com:53530/OPCUA/SecureServer";
Security Settings
OPC UA Security
csharpSecurityConfiguration = new SecurityConfiguration
{
    // Development settings (less secure)
    AutoAcceptUntrustedCertificates = true,
    RejectSHA1SignedCertificates = false,
    MinimumCertificateKeySize = 1024,
    
    // Production settings (more secure)
    AutoAcceptUntrustedCertificates = false,
    RejectSHA1SignedCertificates = true,
    MinimumCertificateKeySize = 2048,
    ApplicationCertificate = new CertificateIdentifier
    {
        StoreType = @"Directory",
        StorePath = @"%CommonApplicationData%\OPC Foundation\CertificateStores\MachineDefault",
        SubjectName = "CN=Industrial IoT Client, O=Company, C=PT"
    }
}
Performance Tuning
Database Optimization
sql-- Indexes for better performance
CREATE INDEX idx_opc_timestamp ON opc_live_data(timestamp DESC);
CREATE INDEX idx_opc_node_id ON opc_live_data(node_id);
CREATE INDEX idx_opc_display_name ON opc_live_data(display_name);

-- Partition table by date (for large datasets)
CREATE TABLE opc_live_data_y2025 PARTITION OF opc_live_data
FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
OPC UA Optimization
csharpTransportQuotas = new TransportQuotas
{
    OperationTimeout = 15000,          // 15 seconds
    MaxStringLength = 1048576,         // 1 MB
    MaxMessageSize = 4194304,          // 4 MB
    MaxArrayLength = 65536,            // 64K items
    MaxByteStringLength = 1048576,     // 1 MB
    MaxBufferSize = 65536              // 64K buffer
}