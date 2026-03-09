# Running Spring Framework Petclinic in Docker

## Prerequisites

- Docker 17.05+ (multi-stage build support)

## Quick Start (H2 in-memory database)

Build and run with defaults — no external database required:

```bash
docker build -t petclinic .
docker run -p 8080:8080 petclinic
```

The application will be available at [http://localhost:8080](http://localhost:8080).

## Build Details

The Dockerfile uses a multi-stage build:

1. **Build stage** — Compiles the WAR using the Maven wrapper and the default `H2` Maven profile. OpenJDK 24 (`public.ecr.aws/docker/library/openjdk:24-jdk-bookworm`) is used as the base image.
2. **Runtime stage** — Deploys the WAR into Apache Tomcat 11.0.18 on the same OpenJDK 24 base.

## Environment Variables

All runtime configuration is driven by environment variables. Defaults match the H2 in-memory profile so the container starts without any extra configuration.

| Variable | Default | Description |
|---|---|---|
| `SPRING_PROFILES_ACTIVE` | `jpa` | Spring persistence profile: `jpa`, `jdbc`, or `spring-data-jpa` |
| `JDBC_DRIVER_CLASS_NAME` | `org.h2.Driver` | JDBC driver class |
| `JDBC_URL` | `jdbc:h2:mem:petclinic` | JDBC connection URL |
| `JDBC_USERNAME` | `sa` | Database username |
| `JDBC_PASSWORD` | *(empty)* | Database password |
| `JPA_DATABASE` | `H2` | Hibernate dialect hint: `H2`, `HSQL`, `MYSQL`, or `POSTGRESQL` |

## Using an External Database

### MySQL

```bash
docker run -p 8080:8080 \
  -e JDBC_DRIVER_CLASS_NAME=com.mysql.cj.jdbc.Driver \
  -e JDBC_URL="jdbc:mysql://host.docker.internal:3306/petclinic?useUnicode=true" \
  -e JDBC_USERNAME=petclinic \
  -e JDBC_PASSWORD=petclinic \
  -e JPA_DATABASE=MYSQL \
  petclinic
```

> **Note:** The MySQL JDBC driver is **not** included in the default build. Rebuild the WAR with the MySQL Maven profile to include it:
> ```bash
> docker build --build-arg MAVEN_PROFILE=MySQL -t petclinic-mysql .
> ```
> This requires changing the `RUN ./mvnw package` line in the Dockerfile to:
> ```dockerfile
> ARG MAVEN_PROFILE=H2
> RUN ./mvnw package -P${MAVEN_PROFILE} -DskipTests -B
> ```

### PostgreSQL

```bash
docker run -p 8080:8080 \
  -e JDBC_DRIVER_CLASS_NAME=org.postgresql.Driver \
  -e JDBC_URL="jdbc:postgresql://host.docker.internal:5432/petclinic" \
  -e JDBC_USERNAME=postgres \
  -e JDBC_PASSWORD=petclinic \
  -e JPA_DATABASE=POSTGRESQL \
  petclinic
```

> Same driver caveat applies — rebuild with `-P PostgreSQL`.

## Changing the Spring Persistence Profile

The application supports three persistence strategies:

```bash
# Use plain JDBC (Spring JdbcTemplate)
docker run -p 8080:8080 -e SPRING_PROFILES_ACTIVE=jdbc petclinic

# Use JPA (Hibernate EntityManager) — default
docker run -p 8080:8080 -e SPRING_PROFILES_ACTIVE=jpa petclinic

# Use Spring Data JPA
docker run -p 8080:8080 -e SPRING_PROFILES_ACTIVE=spring-data-jpa petclinic
```

## Customising the Port

Tomcat listens on port 8080 inside the container. Map it to any host port:

```bash
docker run -p 9090:8080 petclinic
```
