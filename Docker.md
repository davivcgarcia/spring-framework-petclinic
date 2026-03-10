# Docker Guide for Spring Framework Petclinic

This guide explains how to build and run the Spring Framework Petclinic application using Docker, following AWS and cloud-native best practices.

## Table of Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Building the Docker Image](#building-the-docker-image)
- [Running the Container](#running-the-container)
- [Configuration](#configuration)
- [Database Options](#database-options)
- [Health Checks](#health-checks)
- [AWS ECR Deployment](#aws-ecr-deployment)
- [Production Recommendations](#production-recommendations)

## Overview

The Dockerfile uses a **multi-stage build** approach:
- **Stage 1 (Builder)**: Compiles the application using Maven and OpenJDK 17
- **Stage 2 (Runtime)**: Runs the application on Tomcat 11 with OpenJDK 17

**Base Images** (from AWS ECR Public):
- Build: `public.ecr.aws/docker/library/maven:3.9-eclipse-temurin-25`
- Runtime: `public.ecr.aws/docker/library/tomcat:11-jdk25`

## Prerequisites

- Docker Desktop or Docker Engine (20.10+)
- AWS CLI (for ECR operations)
- At least 2GB of free disk space
- Internet connection for downloading dependencies

## Building the Docker Image

### Basic Build

Build the image with a tag:

```bash
docker build -t spring-petclinic:latest .
```

### Build with Custom Tag

```bash
docker build -t spring-petclinic:7.0.3 .
```

### Build with Build Arguments (if needed in future)

```bash
docker build \
  --build-arg MAVEN_OPTS="-Xmx1024m" \
  -t spring-petclinic:latest \
  .
```

The build process will:
1. Download all Maven dependencies (~5-10 minutes first time)
2. Compile the application
3. Package it as a WAR file
4. Deploy to Tomcat

**Expected build time**: 5-10 minutes (first build), 1-2 minutes (subsequent builds with caching)

## Running the Container

### Basic Run (H2 In-Memory Database)

Run the container with default settings (H2 in-memory database):

```bash
docker run -d \
  --name petclinic \
  -p 8080:8080 \
  spring-petclinic:latest
```

Access the application at: **http://localhost:8080**

### Run with Container Logs

To see the application logs:

```bash
docker run -d \
  --name petclinic \
  -p 8080:8080 \
  spring-petclinic:latest

docker logs -f petclinic
```

### Run in Foreground (for debugging)

```bash
docker run --rm \
  --name petclinic \
  -p 8080:8080 \
  spring-petclinic:latest
```

### Stop and Remove Container

```bash
docker stop petclinic
docker rm petclinic
```

## Configuration

### Environment Variables

The application supports the following environment variables:

| Variable | Default Value | Description |
|----------|---------------|-------------|
| `DB_SCRIPT` | `h2` | Database initialization script (h2, mysql, postgresql, hsqldb) |
| `JPA_DATABASE` | `H2` | JPA database type (H2, MYSQL, POSTGRESQL, HSQL) |
| `JDBC_DRIVER_CLASS_NAME` | `org.h2.Driver` | JDBC driver class name |
| `JDBC_URL` | `jdbc:h2:mem:petclinic` | JDBC connection URL |
| `JDBC_USERNAME` | `sa` | Database username |
| `JDBC_PASSWORD` | `""` (empty) | Database password |
| `JPA_SHOW_SQL` | `false` | Show SQL queries in logs |
| `CATALINA_OPTS` | (see Dockerfile) | JVM options for Tomcat |

### Custom JVM Options

Override JVM settings for production:

```bash
docker run -d \
  --name petclinic \
  -p 8080:8080 \
  -e CATALINA_OPTS="-Xms512m -Xmx1024m -XX:+UseG1GC -XX:MaxGCPauseMillis=200" \
  spring-petclinic:latest
```

## Database Options

### Option 1: H2 In-Memory Database (Default)

No additional configuration needed. Data is lost when container stops.

```bash
docker run -d \
  --name petclinic \
  -p 8080:8080 \
  spring-petclinic:latest
```

### Option 2: MySQL Database

Run MySQL container:

```bash
docker network create petclinic-network

docker run -d \
  --name mysql \
  --network petclinic-network \
  -e MYSQL_ROOT_PASSWORD=root \
  -e MYSQL_DATABASE=petclinic \
  -e MYSQL_USER=petclinic \
  -e MYSQL_PASSWORD=petclinic \
  -p 3306:3306 \
  mysql:8.0
```

Run Petclinic with MySQL:

```bash
docker run -d \
  --name petclinic \
  --network petclinic-network \
  -p 8080:8080 \
  -e DB_SCRIPT=mysql \
  -e JPA_DATABASE=MYSQL \
  -e JDBC_DRIVER_CLASS_NAME=com.mysql.cj.jdbc.Driver \
  -e JDBC_URL="jdbc:mysql://mysql:3306/petclinic?useUnicode=true" \
  -e JDBC_USERNAME=petclinic \
  -e JDBC_PASSWORD=petclinic \
  spring-petclinic:latest
```

### Option 3: PostgreSQL Database

Run PostgreSQL container:

```bash
docker network create petclinic-network

docker run -d \
  --name postgres \
  --network petclinic-network \
  -e POSTGRES_DB=petclinic \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=petclinic \
  -p 5432:5432 \
  postgres:15
```

Run Petclinic with PostgreSQL:

```bash
docker run -d \
  --name petclinic \
  --network petclinic-network \
  -p 8080:8080 \
  -e DB_SCRIPT=postgresql \
  -e JPA_DATABASE=POSTGRESQL \
  -e JDBC_DRIVER_CLASS_NAME=org.postgresql.Driver \
  -e JDBC_URL="jdbc:postgresql://postgres:5432/petclinic" \
  -e JDBC_USERNAME=postgres \
  -e JDBC_PASSWORD=petclinic \
  spring-petclinic:latest
```

### Option 4: AWS RDS (Production)

For AWS RDS MySQL:

```bash
docker run -d \
  --name petclinic \
  -p 8080:8080 \
  -e DB_SCRIPT=mysql \
  -e JPA_DATABASE=MYSQL \
  -e JDBC_DRIVER_CLASS_NAME=com.mysql.cj.jdbc.Driver \
  -e JDBC_URL="jdbc:mysql://your-rds-endpoint.us-east-1.rds.amazonaws.com:3306/petclinic?useUnicode=true&useSSL=true" \
  -e JDBC_USERNAME=admin \
  -e JDBC_PASSWORD=your-secure-password \
  spring-petclinic:latest
```

For AWS RDS PostgreSQL:

```bash
docker run -d \
  --name petclinic \
  -p 8080:8080 \
  -e DB_SCRIPT=postgresql \
  -e JPA_DATABASE=POSTGRESQL \
  -e JDBC_DRIVER_CLASS_NAME=org.postgresql.Driver \
  -e JDBC_URL="jdbc:postgresql://your-rds-endpoint.us-east-1.rds.amazonaws.com:5432/petclinic?ssl=true" \
  -e JDBC_USERNAME=postgres \
  -e JDBC_PASSWORD=your-secure-password \
  spring-petclinic:latest
```

## Health Checks

The container includes a built-in health check:

```bash
# Check health status
docker inspect --format='{{.State.Health.Status}}' petclinic

# View health check logs
docker inspect --format='{{range .State.Health.Log}}{{.Output}}{{end}}' petclinic
```

Manual health check:

```bash
curl http://localhost:8080/
```

## AWS ECR Deployment

### Step 1: Authenticate with ECR

```bash
# Get ECR login token (replace region and account-id)
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
```

### Step 2: Tag the Image

```bash
# Tag for ECR (user will create the repository)
docker tag spring-petclinic:latest \
  <account-id>.dkr.ecr.us-east-1.amazonaws.com/spring-petclinic:latest

docker tag spring-petclinic:latest \
  <account-id>.dkr.ecr.us-east-1.amazonaws.com/spring-petclinic:7.0.3
```

### Step 3: Push to ECR

```bash
# Push both tags
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/spring-petclinic:latest
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/spring-petclinic:7.0.3
```

### Step 4: Pull from ECR (on deployment)

```bash
# On your deployment environment
docker pull <account-id>.dkr.ecr.us-east-1.amazonaws.com/spring-petclinic:latest

docker run -d \
  --name petclinic \
  -p 8080:8080 \
  <account-id>.dkr.ecr.us-east-1.amazonaws.com/spring-petclinic:latest
```

## Production Recommendations

### 1. Security Best Practices

- ✅ Runs as non-root user (`petclinic:1001`)
- ✅ Minimal base image (Ubuntu Noble)
- ✅ No secrets in environment variables (use AWS Secrets Manager)
- ✅ Latest security patches from base images

### 2. Resource Limits

Always set resource limits in production:

```bash
docker run -d \
  --name petclinic \
  -p 8080:8080 \
  --memory="1g" \
  --memory-swap="1g" \
  --cpus="1.0" \
  -e CATALINA_OPTS="-Xms512m -Xmx768m -XX:+UseG1GC" \
  spring-petclinic:latest
```

### 3. Logging

Configure logging for production:

```bash
docker run -d \
  --name petclinic \
  -p 8080:8080 \
  --log-driver=awslogs \
  --log-opt awslogs-region=us-east-1 \
  --log-opt awslogs-group=/ecs/petclinic \
  --log-opt awslogs-stream=petclinic-container \
  spring-petclinic:latest
```

### 4. Monitoring

Expose JMX for monitoring:

```bash
docker run -d \
  --name petclinic \
  -p 8080:8080 \
  -p 9010:9010 \
  -e CATALINA_OPTS="-Xms512m -Xmx1024m -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=9010 -Dcom.sun.management.jmxremote.rmi.port=9010 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false" \
  spring-petclinic:latest
```

### 5. Secrets Management

Use AWS Secrets Manager instead of environment variables:

```bash
# Fetch secret from AWS Secrets Manager
DB_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id petclinic/db-password \
  --query SecretString \
  --output text)

docker run -d \
  --name petclinic \
  -p 8080:8080 \
  -e JDBC_PASSWORD="$DB_PASSWORD" \
  spring-petclinic:latest
```

### 6. Docker Compose (Optional)

Create `docker-compose.yml` for easier management:

```yaml
version: '3.8'

services:
  petclinic:
    image: spring-petclinic:latest
    ports:
      - "8080:8080"
    environment:
      - DB_SCRIPT=postgresql
      - JPA_DATABASE=POSTGRESQL
      - JDBC_DRIVER_CLASS_NAME=org.postgresql.Driver
      - JDBC_URL=jdbc:postgresql://postgres:5432/petclinic
      - JDBC_USERNAME=postgres
      - JDBC_PASSWORD=petclinic
    depends_on:
      - postgres
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/"]
      interval: 30s
      timeout: 3s
      retries: 3
      start_period: 60s

  postgres:
    image: postgres:15
    environment:
      - POSTGRES_DB=petclinic
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=petclinic
    ports:
      - "5432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data

volumes:
  postgres-data:
```

Run with Docker Compose:

```bash
docker-compose up -d
docker-compose logs -f
docker-compose down
```

## Troubleshooting

### Container won't start

Check logs:
```bash
docker logs petclinic
```

### Database connection issues

Verify database is accessible:
```bash
# For MySQL
docker exec petclinic curl -v telnet://mysql:3306

# For PostgreSQL
docker exec petclinic curl -v telnet://postgres:5432
```

### Out of memory

Increase heap size:
```bash
docker run -d \
  --name petclinic \
  -p 8080:8080 \
  --memory="2g" \
  -e CATALINA_OPTS="-Xms512m -Xmx1536m -XX:+UseG1GC" \
  spring-petclinic:latest
```

### Slow startup

The application takes 30-60 seconds to start. Wait for the health check to pass:
```bash
docker logs -f petclinic
# Look for "Server startup in [XXXX] milliseconds"
```

## Additional Resources

- [Spring Petclinic GitHub](https://github.com/spring-petclinic/spring-framework-petclinic)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [Tomcat Docker Official Images](https://hub.docker.com/_/tomcat)

## Support

For issues specific to this Docker implementation, please check the application logs:
```bash
docker logs petclinic
```

For application-specific issues, refer to the [main README](readme.md).
