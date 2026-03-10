# Multi-stage Dockerfile for Spring Framework Petclinic
# Following AWS and cloud-native best practices

# ============================================
# Stage 1: Build Stage
# ============================================
FROM public.ecr.aws/docker/library/maven:3.9-eclipse-temurin-25 AS builder

# Set working directory
WORKDIR /build

# Copy all source files
COPY . .

# Build the application (produces petclinic.war)
# Skip tests for faster builds (tests should run in CI/CD pipeline)
RUN mvn clean package -DskipTests -B

# Verify the WAR file was created
RUN ls -lh /build/target/petclinic.war

# ============================================
# Stage 2: Runtime Stage
# ============================================
FROM public.ecr.aws/docker/library/tomcat:11-jdk25

# Metadata labels following OCI image spec
LABEL maintainer="DevOps Team" \
      org.opencontainers.image.title="Spring Framework Petclinic" \
      org.opencontainers.image.description="Spring Framework Petclinic application containerized with Tomcat 11" \
      org.opencontainers.image.vendor="Spring Petclinic Community" \
      org.opencontainers.image.version="7.0.3"

# Set environment variables with sensible defaults
# Database configuration (H2 in-memory by default)
ENV DB_SCRIPT=h2 \
    JPA_DATABASE=H2 \
    JDBC_DRIVER_CLASS_NAME=org.h2.Driver \
    JDBC_URL=jdbc:h2:mem:petclinic \
    JDBC_USERNAME=sa \
    JDBC_PASSWORD="" \
    JPA_SHOW_SQL=false \
    CATALINA_OPTS="-Xms256m -Xmx512m -XX:+UseG1GC -XX:MaxGCPauseMillis=200"

# Create non-root user for security
RUN groupadd -r petclinic -g 1001 && \
    useradd -r -g petclinic -u 1001 -m -s /sbin/nologin petclinic

# Install required utilities (curl for health checks, unzip for WAR extraction)
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl unzip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Remove default Tomcat webapps and deploy our application
RUN rm -rf /usr/local/tomcat/webapps/* && \
    mkdir -p /usr/local/tomcat/webapps/ROOT

# Copy the WAR file from builder stage and extract it to ROOT
COPY --from=builder /build/target/petclinic.war /usr/local/tomcat/webapps/ROOT.war
RUN cd /usr/local/tomcat/webapps && \
    unzip -q ROOT.war -d ROOT && \
    rm ROOT.war

# Set proper permissions
RUN chown -R petclinic:petclinic /usr/local/tomcat

# Health check endpoint
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

# Switch to non-root user
USER petclinic

# Expose Tomcat port
EXPOSE 8080

# Set working directory
WORKDIR /usr/local/tomcat

# Start Tomcat with system property overrides for database configuration
CMD ["catalina.sh", "run", \
     "-Djdbc.driverClassName=${JDBC_DRIVER_CLASS_NAME}", \
     "-Djdbc.url=${JDBC_URL}", \
     "-Djdbc.username=${JDBC_USERNAME}", \
     "-Djdbc.password=${JDBC_PASSWORD}", \
     "-Djpa.database=${JPA_DATABASE}", \
     "-Djpa.showSql=${JPA_SHOW_SQL}", \
     "-Ddb.script=${DB_SCRIPT}"]
