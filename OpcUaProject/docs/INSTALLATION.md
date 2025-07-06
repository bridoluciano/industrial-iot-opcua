System Requirements
ComponentMinimumRecommendedOSWindows 10Windows 11RAM4 GB8 GB+Storage2 GB5 GB+.NET Framework4.84.8PostgreSQL12+15+
Step-by-Step Installation
1. Development Environment
bash# Install Visual Studio 2022 Community (Free)
# Download from: https://visualstudio.microsoft.com/downloads/

# Required Workloads:
# - .NET desktop development
# - Data storage and processing
2. PostgreSQL Setup
bash# Option A: Native Installation
# Download from: https://www.postgresql.org/download/windows/
# Install with default settings
# Username: postgres
# Password: postgres123

# Option B: Docker (Recommended)
docker run -d \
  --name postgres-iot \
  -e POSTGRES_PASSWORD=postgres123 \
  -e POSTGRES_DB=OpcUaDb \
  -p 5432:5432 \
  postgres:15

# Verify installation
docker exec -it postgres-iot psql -U postgres -c "SELECT version();"
3. OPC UA Simulator
bash# Download Prosys OPC UA Simulation Server
# URL: https://www.prosysopc.com/products/opc-ua-simulation-server/
# Install free 30-day trial
# Default endpoint: opc.tcp://localhost:53530/OPCUA/SimulationServer
4. Project Setup
bash# Clone repository
git clone https://github.com/[username]/industrial-iot-opcua.git
cd industrial-iot-opcua

# Open in Visual Studio
start OpcUaProject.sln

# Build solution
Ctrl+Shift+B