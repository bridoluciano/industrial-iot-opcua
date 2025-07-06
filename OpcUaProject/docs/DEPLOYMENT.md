using Microsoft.Extensions.Hosting;
using System.Security.Policy;

Development Deployment
bash# Local development setup
1. Install Visual Studio 2022
2. Setup PostgreSQL (Docker recommended)
3. Install OPC UA Simulator
4. Clone and build project
5. Run application (F5)
Production Deployment
bash# Windows Service deployment
1. Install as Windows Service
2. Configure production connection strings
3. Setup SSL certificates
4. Enable security policies
5. Configure logging and monitoring
Docker Deployment
dockerfile# Dockerfile example
FROM mcr.microsoft.com/dotnet/framework/runtime:4.8
WORKDIR /app
COPY bin/Release/ .
ENTRYPOINT ["OpcUaProject.exe"]
yaml# docker-compose.yml
version: '3.8'
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: postgres123
      POSTGRES_DB: OpcUaDb
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
  
  opcua-client:
    build: .
depends_on:
      - postgres
    environment:
      - DB_CONNECTION=Host=postgres;Port=5432;Database=OpcUaDb;Username=postgres;Password=postgres123
volumes:
  postgres_data:Development Deployment
bash# Local development setup
1. Install Visual Studio 2022
2. Setup PostgreSQL (Docker recommended)
3. Install OPC UA Simulator
4. Clone and build project
5. Run application (F5)
Production Deployment
bash# Windows Service deployment
1. Install as Windows Service
2. Configure production connection strings
3. Setup SSL certificates
4. Enable security policies
5. Configure logging and monitoring
Docker Deployment
dockerfile# Dockerfile example
FROM mcr.microsoft.com/dotnet/framework/runtime:4.8
WORKDIR /app
COPY bin/Release/ .
ENTRYPOINT ["OpcUaProject.exe"]
yaml# docker-compose.yml
version: '3.8'
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: postgres123
      POSTGRES_DB: OpcUaDb
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
  
  opcua-client:
    build: .
depends_on:
      - postgres
    environment:
      - DB_CONNECTION=Host=postgres;Port=5432;Database=OpcUaDb;Username=postgres;Password=postgres123
volumes:
  postgres_data: