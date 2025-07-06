Core Classes
Program Class
csharpnamespace OpcUaProject
{
    class Program
    {
        static async Task Main(string[] args)
        // Main entry point for the application
    }
}
Key Methods
Database Operations
csharp// Create Database
var checkDbSql = "SELECT 1 FROM pg_database WHERE datname = 'OpcUaDb'";
var createDbSql = "CREATE DATABASE \"OpcUaDb\"";

// Create Table
var createTableSql = @"
    CREATE TABLE IF NOT EXISTS opc_live_data (
        id SERIAL PRIMARY KEY,
        node_id VARCHAR(200) NOT NULL,
        display_name VARCHAR(200),
        value TEXT,
        data_type VARCHAR(50),
        timestamp TIMESTAMP DEFAULT NOW(),
        quality VARCHAR(50)
    )";

// Insert Data
var insertSql = @"
    INSERT INTO opc_live_data (node_id, display_name, value, data_type, quality) 
    VALUES (@nodeId, @displayName, @value, @dataType, @quality)";
OPC UA Operations
csharp// Configuration
var config = new ApplicationConfiguration()
{
    ApplicationName = "Coficab Industrial IoT Client",
    ApplicationType = ApplicationType.Client,
    ApplicationUri = "urn:coficab:industrial:iot:client",
    SecurityConfiguration = new SecurityConfiguration
    {
        AutoAcceptUntrustedCertificates = true,
        RejectSHA1SignedCertificates = false,
        MinimumCertificateKeySize = 1024
    }
};

// Connection
var endpointDescription = CoreClientUtils.SelectEndpoint(endpointUrl, false, 15000);
var session = await Session.Create(config, endpoint, false, "Client", 60000, null, null);

// Browse Nodes
var browser = new Browser(session);
var references = browser.Browse(ObjectIds.ObjectsFolder);

// Read Values
var readValueIds = new ReadValueIdCollection();
session.Read(null, 0, TimestampsToReturn.Both, readValueIds, out results, out diagnostics);
Data Models
OPC Data Structure
csharppublic class OpcDataPoint
{
    public string NodeId { get; set; }
    public string DisplayName { get; set; }
    public object Value { get; set; }
    public string DataType { get; set; }
    public string Quality { get; set; }
    public DateTime Timestamp { get; set; }
}