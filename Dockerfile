# ---- Build Stage ----
FROM public.ecr.aws/docker/library/openjdk:24-jdk-bookworm AS build

WORKDIR /app

# Copy Maven wrapper and POM first to cache dependencies
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
RUN chmod +x mvnw && ./mvnw dependency:resolve -B

# Copy source and build the WAR (default H2 profile)
COPY src/ src/
RUN ./mvnw package -DskipTests -B

# ---- Runtime Stage ----
FROM public.ecr.aws/docker/library/openjdk:24-jdk-bookworm

ENV TOMCAT_VERSION=11.0.18
ENV CATALINA_HOME=/opt/tomcat

# Spring profile for persistence layer: jpa | jdbc | spring-data-jpa
ENV SPRING_PROFILES_ACTIVE=jpa

# JDBC defaults (H2 in-memory — matches the default Maven H2 build profile)
ENV JDBC_DRIVER_CLASS_NAME=org.h2.Driver
ENV JDBC_URL=jdbc:h2:mem:petclinic
ENV JDBC_USERNAME=sa
ENV JDBC_PASSWORD=

# JPA vendor adapter database type: H2 | HSQL | MYSQL | POSTGRESQL
ENV JPA_DATABASE=H2

# Download and install Apache Tomcat
RUN apt-get update && apt-get install -y --no-install-recommends curl && \
    curl -fsSL "https://archive.apache.org/dist/tomcat/tomcat-11/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz" \
      | tar xz -C /opt && \
    mv /opt/apache-tomcat-${TOMCAT_VERSION} ${CATALINA_HOME} && \
    rm -rf ${CATALINA_HOME}/webapps/* && \
    apt-get purge -y --auto-remove curl && \
    rm -rf /var/lib/apt/lists/*

# Deploy the WAR as the ROOT application
COPY --from=build /app/target/petclinic.war ${CATALINA_HOME}/webapps/ROOT.war

EXPOSE 8080

# Entrypoint script passes JDBC/JPA properties as system properties so Spring's
# system-properties-mode="OVERRIDE" picks them up at runtime
CMD ["sh", "-c", "${CATALINA_HOME}/bin/catalina.sh run -Dspring.profiles.active=${SPRING_PROFILES_ACTIVE} -Djdbc.driverClassName=${JDBC_DRIVER_CLASS_NAME} -Djdbc.url=${JDBC_URL} -Djdbc.username=${JDBC_USERNAME} -Djdbc.password=${JDBC_PASSWORD} -Djpa.database=${JPA_DATABASE}"]
