using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Opc.Ua;
using Opc.Ua.Client;
using Opc.Ua.Configuration;
using Npgsql;
using Serilog;

namespace OpcUaProject
{
    class Program
    {
        static async Task Main(string[] args)
        {
            // Configure logging
            Log.Logger = new LoggerConfiguration()
                .MinimumLevel.Information()
                .WriteTo.Console()
                .CreateLogger();

            Console.WriteLine("🚀 Coficab OPC UA Client Starting...");

            // Configuration
            var endpointUrl = "opc.tcp://COFPT-LAP-124.coficab.com:53530/OPCUA/SimulationServer";

            // Connection strings
            var masterConnectionString = "Host=localhost;Port=5432;Database=postgres;Username=postgres;Password=postgres123";
            var connectionString = "Host=localhost;Port=5432;Database=OpcUaDb;Username=postgres;Password=postgres123";

            try
            {
                // 1. Connect to master database and create OpcUaDb if it doesn't exist
                Console.WriteLine("🔌 Connecting to PostgreSQL master database...");
                using (var masterConnection = new NpgsqlConnection(masterConnectionString))
                {
                    await masterConnection.OpenAsync();
                    Console.WriteLine("✅ Connected to PostgreSQL server!");

                    // Check if database exists
                    var checkDbSql = "SELECT 1 FROM pg_database WHERE datname = 'OpcUaDb'";
                    using (var checkCmd = new NpgsqlCommand(checkDbSql, masterConnection))
                    {
                        var result = await checkCmd.ExecuteScalarAsync();
                        if (result == null)
                        {
                            Console.WriteLine("📦 Creating database 'OpcUaDb'...");
                            var createDbSql = "CREATE DATABASE \"OpcUaDb\"";
                            using (var createCmd = new NpgsqlCommand(createDbSql, masterConnection))
                            {
                                await createCmd.ExecuteNonQueryAsync();
                                Console.WriteLine("✅ Database 'OpcUaDb' created successfully!");
                            }
                        }
                        else
                        {
                            Console.WriteLine("✅ Database 'OpcUaDb' already exists!");
                        }
                    }
                }

                // 2. Connect to OpcUaDb database
                Console.WriteLine("🔌 Connecting to OpcUaDb database...");
                using (var connection = new NpgsqlConnection(connectionString))
                {
                    await connection.OpenAsync();
                    Console.WriteLine("✅ Connected to OpcUaDb successfully!");

                    // 3. Create database table
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

                    using (var command = new NpgsqlCommand(createTableSql, connection))
                    {
                        await command.ExecuteNonQueryAsync();
                        Console.WriteLine("✅ Database table 'opc_live_data' ready!");
                    }

                    // 4. Configure OPC UA Client
                    Console.WriteLine("⚙️ Configuring OPC UA client...");
                    var config = new ApplicationConfiguration()
                    {
                        ApplicationName = "Coficab Industrial IoT Client",
                        ApplicationType = ApplicationType.Client,
                        ApplicationUri = "urn:coficab:industrial:iot:client",

                        SecurityConfiguration = new SecurityConfiguration
                        {
                            AutoAcceptUntrustedCertificates = true,
                            RejectSHA1SignedCertificates = false,
                            MinimumCertificateKeySize = 1024,
                            ApplicationCertificate = new CertificateIdentifier()
                        },

                        TransportQuotas = new TransportQuotas
                        {
                            OperationTimeout = 15000,
                            MaxStringLength = 1048576,
                            MaxMessageSize = 4194304
                        },

                        ClientConfiguration = new ClientConfiguration
                        {
                            DefaultSessionTimeout = 60000
                        }
                    };

                    await config.Validate(ApplicationType.Client);
                    Console.WriteLine("✅ OPC UA configuration ready!");

                    // 5. Connect to OPC UA Server
                    Console.WriteLine($"🔌 Connecting to OPC UA server...");
                    Console.WriteLine($"Endpoint: {endpointUrl}");

                    var endpointDescription = CoreClientUtils.SelectEndpoint(endpointUrl, false, 15000);
                    var endpointConfiguration = EndpointConfiguration.Create(config);
                    var endpoint = new ConfiguredEndpoint(null, endpointDescription, endpointConfiguration);

                    using (var session = await Session.Create(
                        config,
                        endpoint,
                        false,
                        "CoficabIndustrialClient",
                        60000,
                        null,
                        null))
                    {
                        Console.WriteLine("✅ Connected to OPC UA Server!");
                        Console.WriteLine($"📊 Session Name: {session.SessionName}");

                        // 6. Browse OPC UA nodes
                        Console.WriteLine("🔍 Browsing OPC UA nodes...");
                        var browser = new Browser(session);
                        var references = browser.Browse(ObjectIds.ObjectsFolder);

                        Console.WriteLine($"📂 Found {references.Count} root objects:");

                        var nodesToRead = new List<NodeId>();
                        var nodeInfo = new Dictionary<NodeId, string>();

                        // Find readable variables
                        foreach (var reference in references.Take(5))
                        {
                            Console.WriteLine($"  📁 {reference.DisplayName}");

                            try
                            {
                                // Convert ExpandedNodeId to NodeId
                                var nodeId = ExpandedNodeId.ToNodeId(reference.NodeId, session.NamespaceUris);
                                var children = browser.Browse(nodeId);

                                foreach (var child in children.Take(10))
                                {
                                    if (child.NodeClass == NodeClass.Variable)
                                    {
                                        var childNodeId = ExpandedNodeId.ToNodeId(child.NodeId, session.NamespaceUris);
                                        nodesToRead.Add(childNodeId);
                                        nodeInfo[childNodeId] = child.DisplayName.Text ?? "Unknown";
                                        Console.WriteLine($"    📊 {child.DisplayName} [{child.NodeId}]");
                                    }

                                    if (nodesToRead.Count >= 15) break;
                                }
                            }
                            catch (Exception ex)
                            {
                                Console.WriteLine($"    ⚠️ Could not browse {reference.DisplayName}: {ex.Message}");
                            }

                            if (nodesToRead.Count >= 15) break;
                        }

                        // 7. Read values and store in database
                        if (nodesToRead.Count > 0)
                        {
                            Console.WriteLine($"\n📖 Reading {nodesToRead.Count} variables...");

                            // Create ReadValueIdCollection
                            var readValueIds = new ReadValueIdCollection();
                            foreach (var nodeId in nodesToRead)
                            {
                                readValueIds.Add(new ReadValueId()
                                {
                                    NodeId = nodeId,
                                    AttributeId = Attributes.Value
                                });
                            }

                            // Read values
                            DataValueCollection results;
                            DiagnosticInfoCollection diagnosticInfos;

                            session.Read(
                                null,
                                0,
                                TimestampsToReturn.Both,
                                readValueIds,
                                out results,
                                out diagnosticInfos);

                            var successCount = 0;

                            for (int i = 0; i < nodesToRead.Count && i < results.Count; i++)
                            {
                                var nodeId = nodesToRead[i];
                                var value = results[i];
                                var displayName = nodeInfo[nodeId];

                                if (StatusCode.IsGood(value.StatusCode))
                                {
                                    Console.WriteLine($"  ✅ {displayName}: {value.Value} [{value.StatusCode}]");

                                    // Store in PostgreSQL
                                    try
                                    {
                                        var insertSql = @"
                                            INSERT INTO opc_live_data (node_id, display_name, value, data_type, quality) 
                                            VALUES (@nodeId, @displayName, @value, @dataType, @quality)";

                                        using (var insertCmd = new NpgsqlCommand(insertSql, connection))
                                        {
                                            insertCmd.Parameters.AddWithValue("nodeId", nodeId.ToString());
                                            insertCmd.Parameters.AddWithValue("displayName", displayName);
                                            insertCmd.Parameters.AddWithValue("value", value.Value?.ToString() ?? "null");
                                            insertCmd.Parameters.AddWithValue("dataType", value.Value?.GetType().Name ?? "Unknown");
                                            insertCmd.Parameters.AddWithValue("quality", value.StatusCode.ToString());

                                            await insertCmd.ExecuteNonQueryAsync();
                                            successCount++;
                                        }
                                    }
                                    catch (Exception ex)
                                    {
                                        Console.WriteLine($"    ❌ Failed to store {displayName}: {ex.Message}");
                                    }
                                }
                                else
                                {
                                    Console.WriteLine($"  ❌ {displayName}: {value.StatusCode}");
                                }
                            }

                            Console.WriteLine($"✅ Stored {successCount} values in PostgreSQL!");

                            // 8. Query back from database
                            Console.WriteLine("\n💾 Latest data from PostgreSQL:");
                            var selectSql = "SELECT * FROM opc_live_data ORDER BY timestamp DESC LIMIT 10";
                            using (var selectCmd = new NpgsqlCommand(selectSql, connection))
                            {
                                using (var reader = await selectCmd.ExecuteReaderAsync())
                                {
                                    int count = 0;
                                    while (await reader.ReadAsync() && count < 10)
                                    {
                                        Console.WriteLine($"  🔹 {reader["display_name"]}: {reader["value"]} @ {reader["timestamp"]}");
                                        count++;
                                    }
                                }
                            }
                        }
                        else
                        {
                            Console.WriteLine("❌ No readable variables found!");
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Error: {ex.Message}");
                if (ex.InnerException != null)
                {
                    Console.WriteLine($"Inner Exception: {ex.InnerException.Message}");
                }
            }

            Console.WriteLine("\n🎯 OPC UA Client completed!");
            Console.WriteLine("Press any key to exit...");
            Console.ReadKey();
        }
    }
}