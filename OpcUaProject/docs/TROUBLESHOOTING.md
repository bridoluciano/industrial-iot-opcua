Common Issues and Solutions
Database Connection Issues
Problem: database "OpcUaDb" does not exist
bashSolution:
1. Ensure PostgreSQL is running: docker ps
2. Check connection string
3. Verify database user permissions
4. Application auto-creates database on first run
Problem: password authentication failed
bashSolution:
1. Verify PostgreSQL credentials
2. Check pg_hba.conf authentication method
3. Reset password: ALTER USER postgres PASSWORD 'postgres123';
OPC UA Connection Issues
Problem: Could not connect to OPC UA server
bashSolution:
1. Verify OPC UA server is running
2. Check endpoint URL format
3. Verify network connectivity: telnet server-ip 53530
4. Check firewall settings
5. Validate security settings
Problem: Certificate validation failed
bashSolution:
1. Set AutoAcceptUntrustedCertificates = true (development)
2. Install server certificate in trusted store
3. Configure proper certificate paths
Application Issues
Problem: No readable variables found
bashSolution:
1. Check OPC UA server simulation status
2. Verify node browse permissions
3. Check namespace configuration
4. Enable additional security policies
Problem: Package version conflicts
bashSolution:
1. Clean solution: Build → Clean Solution
2. Delete bin/ and obj/ folders
3. Restore packages: Tools → NuGet → Restore
4. Rebuild solution
Performance Issues
Problem: Slow data insertion

-- Solution: Batch insertions
BEGIN;
INSERT INTO opc_live_data (node_id, display_name, value, data_type, quality) VALUES
  ('ns=3;i=1001', 'Counter', '100', 'Int32', 'Good'),
  ('ns=3;i=1002', 'Temperature', '25.5', 'Double', 'Good'),
  ('ns=3;i=1003', 'Pressure', '1.2', 'Double', 'Good');
COMMIT;

Problem: High memory usage
// Solution: Dispose resources properly
using (var connection = new NpgsqlConnection(connectionString))
using (var session = await Session.Create(...))
{
    // Your code here
} // Automatic disposal